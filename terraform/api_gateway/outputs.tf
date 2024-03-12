output "api_gateway_id" {
  description = "Api Gateway ID"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_gateway_stage_name" {
  description = "Api Gateway Stage Name"
  value       = aws_api_gateway_stage.api.stage_name
}
