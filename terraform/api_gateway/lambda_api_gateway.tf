data "aws_caller_identity" "this" {}

# data "aws_vpc_endpoint" "vpce" {
#   vpc_id       = var.vpc_id
#   service_name = "com.amazonaws.${var.aws_region}.execute-api"
# }

locals {
  # Common tags to be assigned to all resources
  api_gateway_zone_ids = {
    "us-east-1" = "Z1UJRXOUMOOFQ8"
    "sa-east-1" = "ZCMLWB8V5SYIT"
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name              = "uncover-${var.environment}-${var.lambda_function_name}-api-gateway"
  put_rest_api_mode = "merge"


  dynamic "endpoint_configuration" {
    for_each = var.endpoint_configuration == "PRIVATE" ? [1] : []
    content {
      types            = [var.endpoint_configuration]
      vpc_endpoint_ids = [data.aws_vpc_endpoint.vpce.id]
    }
  }

  dynamic "endpoint_configuration" {
    for_each = var.endpoint_configuration == "PRIVATE" ? [] : [1]
    content {
      types = ["REGIONAL"]
    }
  }
}

resource "aws_api_gateway_resource" "api" {
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_method" "api" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.api.id
  http_method   = "ANY"
  authorization = "NONE"

  api_key_required = var.api_key
}

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.api.id
  http_method             = aws_api_gateway_method.api.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn
}

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"

  api_key_required = var.api_key
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.api,
      aws_api_gateway_resource.api,
      aws_api_gateway_method.api,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name
}

data "aws_iam_policy_document" "api" {
  count = var.endpoint_configuration == "PRIVATE" ? 1 : 0
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.api.execution_arn}/${var.stage_name}/OPTIONS/*", "${aws_api_gateway_rest_api.api.execution_arn}/${var.stage_name}/*/*"]
  }

  statement {
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.api.execution_arn}/${var.stage_name}/OPTIONS/*", "${aws_api_gateway_rest_api.api.execution_arn}/${var.stage_name}/*/*"]

    # condition {
    #   test     = "StringNotEquals"
    #   variable = "aws:SourceVpce"
    #   values   = [data.aws_vpc_endpoint.vpce.id]
    # }
  }
}

resource "aws_api_gateway_rest_api_policy" "api" {
  count       = var.endpoint_configuration == "PRIVATE" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.api.id
  policy      = data.aws_iam_policy_document.api[count.index].json
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  qualifier     = var.stage_name

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}
