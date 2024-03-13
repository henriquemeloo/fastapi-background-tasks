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

resource "aws_api_gateway_resource" "any" {
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{test}"
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_method" "any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.any.id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = var.api_key
  request_parameters   = {
    "method.request.path.test" = true
    "method.request.header.InvocationType" = true
  }
}

resource "aws_api_gateway_integration" "any" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.any.id
  http_method             = aws_api_gateway_method.any.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = var.lambda_function_invoke_arn
  content_handling     = "CONVERT_TO_TEXT"
  request_parameters = {
    "integration.request.header.X-Amz-Invocation-Type" = "method.request.header.InvocationType"
  }
  request_templates = {
    "application/json" = <<-EOT
      ##  See https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-mapping-template-reference.html
      ##  This template will pass through all parameters including path, querystring, header, stage variables, and context through to the integration endpoint via the body/payload
      #set($allParams = $input.params())
      {
      "body-json" : $input.json('$'),
      "params" : {
      #foreach($type in $allParams.keySet())
          #set($params = $allParams.get($type))
      "$type" : {
          #foreach($paramName in $params.keySet())
          "$paramName" : "$util.escapeJavaScript($params.get($paramName))"
              #if($foreach.hasNext),#end
          #end
      }
          #if($foreach.hasNext),#end
      #end
      },
      "stage-variables" : {
      #foreach($key in $stageVariables.keySet())
      "$key" : "$util.escapeJavaScript($stageVariables.get($key))"
          #if($foreach.hasNext),#end
      #end
      },
      "context" : {
          "account-id" : "$context.identity.accountId",
          "api-id" : "$context.apiId",
          "api-key" : "$context.identity.apiKey",
          "authorizer-principal-id" : "$context.authorizer.principalId",
          "caller" : "$context.identity.caller",
          "cognito-authentication-provider" : "$context.identity.cognitoAuthenticationProvider",
          "cognito-authentication-type" : "$context.identity.cognitoAuthenticationType",
          "cognito-identity-id" : "$context.identity.cognitoIdentityId",
          "cognito-identity-pool-id" : "$context.identity.cognitoIdentityPoolId",
          "http-method" : "$context.httpMethod",
          "stage" : "$context.stage",
          "source-ip" : "$context.identity.sourceIp",
          "user" : "$context.identity.user",
          "user-agent" : "$context.identity.userAgent",
          "user-arn" : "$context.identity.userArn",
          "request-id" : "$context.requestId",
          "resource-id" : "$context.resourceId",
          "resource-path" : "$context.resourcePath"
          }
      }
    EOT
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  qualifier     = var.stage_name

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.any,
      aws_api_gateway_resource.any,
      aws_api_gateway_method.any,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
