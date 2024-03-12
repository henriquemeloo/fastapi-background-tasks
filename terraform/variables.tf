## General Config ##

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

## Lambda Config ##

variable "container" {
  description = "If lambda will use container"
  type        = bool
  default     = true
}

variable "function_name" {
  description = "Function Name"
  type        = string
}

variable "description" {
  description = "Description"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Runtime"
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Memory size"
  type        = number
  default     = 128
}

variable "concurrency" {
  description = "Amount of concurrent lambda. 0 to disable lambda"
  type        = number
  default     = -1
}


variable "timeout" {
  description = "Timeout"
  type        = number
  default     = 60
}

variable "policy_statements" {
  description = "Map of dynamic policy statements to attach to Lambda Function role"
  type        = any
  default     = {}
}

variable "handler" {
  description = "Lambda Handler"
  type        = string
  default     = ""
}

variable "env" {
  description = "Enviroment Variables"
  type        = map(any)
  default     = {}
}

variable "bucket" {
  description = "Bucket name of lambda"
  type        = string
  default     = ""
}

variable "bucket_key" {
  description = "Bucket key of lambda"
  type        = string
  default     = ""
}

variable "endpoint_configuration" {
  description = "Type of endpoint. REGIONAL, PRIVATE or EDGE"
  type        = string
  default     = "PRIVATE"
}

## Monitoring ##

variable "cloudwatch_retention_days" {
  description = "Cloudwatch retention days"
  type        = number
  default     = 1
}

## Triggers ##

variable "trigger_api_gateway" {
  description = "Trigger with api gateway"
  type        = bool
  default     = true
}

variable "subdomain_name" {
  description = "Subdomain for route53"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "API Gateway Stage name"
  type        = string
  default     = "api"
}

variable "api_key" {
  description = "Api Key Requirement"
  type        = bool
  default     = false
}

