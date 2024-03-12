# module "vpc" {
#   source = "terraform-aws-modules/vpc/aws"

#   name = "fastapi-background-tasks-test"
#   cidr = "10.0.0.0/16"

#   azs             = ["us-east-1a"]
#   private_subnets = ["10.0.1.0/24"]

#   tags = {
#     Environment = "dev"
#   }
# }

# resource "aws_vpc_endpoint" "apigw" {
#   vpc_id            = module.vpc.vpc_id
#   service_name      = "com.amazonaws.${var.aws_region}.execute-api"
#   vpc_endpoint_type = "Interface"
#   subnet_ids        = module.vpc.private_subnets
# }

data "aws_caller_identity" "this" {}


## Section to get secrets from Parameter Store ##
locals {
  ssm_request = {
    for k, v in var.env : k => v
    if startswith(v, "parameter::")
  }
  raw_env = {
    for k, v in var.env : k => v
    if !startswith(v, "parameter::")
  }
  secrets_target = {
    for k, v in module.store_read.values : keys(local.ssm_request)[k] => v
  }
}

module "store_read" {
  source  = "cloudposse/ssm-parameter-store/aws"
  version = "0.11.0"

  parameter_read = values({ for s in local.ssm_request : s => replace(s, "parameter::", "") })
}

resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSLambdaExecute",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    # "arn:aws:iam::${data.aws_caller_identity.this.account_id}:policy/${aws_iam_policy.lambda.name}"
  ]
}

# resource "aws_iam_policy" "lambda" {
#   name = "${var.function_name}-policy"
#   policy = jsonencode({
#     Version   = "2012-10-17"
#     Statement = var.policy_statements
#   })
# }

data "aws_lambda_function" "lambda" {
  function_name = aws_lambda_function.lambda.function_name
}

resource "aws_lambda_function" "lambda" {
  function_name                  = var.function_name
  description                    = var.description
  handler                        = var.container == false ? var.handler : null
  runtime                        = var.container == false ? var.runtime : null
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  role                           = aws_iam_role.lambda.arn
  reserved_concurrent_executions = var.concurrency
  package_type                   = var.container == true ? "Image" : "Zip"

  s3_bucket = var.container == false ? "uncover-${var.environment}-foundation-${var.aws_region}-artifacts" : null
  s3_key    = var.container == false ? "lambda/templates/lambda_code.zip" : null
  layers    = length(aws_lambda_layer_version.lambda_layer) >= 1 ? aws_lambda_layer_version.lambda_layer[*].arn : null

  # Container Image
  image_uri = var.container == true ? "${data.aws_caller_identity.this.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/uncover-${var.environment}-foundation-${var.aws_region}-template:latest" : null

  environment {
    variables = merge(local.raw_env, local.secrets_target)
  }


  lifecycle {
    ignore_changes = [image_uri, s3_bucket, s3_key, layers, environment, memory_size, timeout]
  }

  # vpc_config {
  #   subnet_ids         = module.vpc.private_subnets
  #   security_group_ids = [module.vpc.default_security_group_id]
  # }

  tags = {
    env       = var.environment
    region    = var.aws_region
    Terraform = "true"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.cloudwatch_retention_days
}

resource "aws_lambda_alias" "live" {
  name             = var.stage_name
  description      = "Active Version"
  function_name    = aws_lambda_function.lambda.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [
      function_version,
    ]
  }
}

resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name = "${var.function_name}-layer"

  count = var.container == false ? 1 : 0

  compatible_runtimes = ["${var.runtime}"]
  s3_bucket           = "uncover-${var.environment}-foundation-${var.aws_region}-artifacts"
  s3_key              = "lambda/templates/lambda_layer.zip"
  skip_destroy        = false
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  count = var.container == true ? 1 : 0

  repository_name                 = var.function_name
  repository_force_delete         = true
  create_repository_policy        = false
  attach_repository_policy        = false
  repository_image_tag_mutability = "MUTABLE"
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 15 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 15
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform = "true"
  }
}

## API Gateway ##
module "api_gateway" {
  source = "./api_gateway"

  count = var.trigger_api_gateway == true ? 1 : 0

  aws_region                 = var.aws_region
  environment                = var.environment
  endpoint_configuration     = var.endpoint_configuration
  lambda_function_name       = aws_lambda_function.lambda.function_name
  lambda_function_invoke_arn = aws_lambda_alias.live.invoke_arn
  subdomain_name             = var.subdomain_name
  # vpc_id                     = module.vpc.vpc_id
  stage_name = var.stage_name
  api_key    = var.api_key

  # depends_on = [aws_vpc_endpoint.apigw]
}

