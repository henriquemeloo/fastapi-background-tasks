## General Config ##

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "endpoint_configuration" {
  description = "Type of endpoint. REGIONAL, PRIVATE or EDGE"
  type        = string
  default     = "PRIVATE"
}

variable "lambda_function_name" {
  description = "Lambda Function Name for Lambda Proxy"
  type        = string
  default     = ""
}

variable "lambda_function_invoke_arn" {
  description = "Lambda Function ARN for Lambda Proxy"
  type        = string
  default     = ""
}

variable "subdomain_name" {
  description = "Subdomain for route53"
  type        = string
  default     = ""
}

# variable "vpc_id" {
#   description = "VPC Id for VPCE"
#   type        = string
# }

variable "stage_name" {
  description = "Stage Name"
  type        = string
}

variable "api_key" {
  description = "Api Key Requirement"
  type        = bool
  default     = false
}
