output "id" {
  description = "ID of the REST API."
  value       = aws_api_gateway_rest_api.this.id
}

output "arn" {
  description = "Execution ARN, which is what a Lambda permission's source_arn is built from."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "root_resource_id" {
  description = "ID of the API's root resource."
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

output "invoke_url" {
  description = "URL the stage is served at."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "stage_name" {
  description = "Name of the deployed stage."
  value       = aws_api_gateway_stage.this.stage_name
}

output "log_group_name" {
  description = "CloudWatch log group holding access logs."
  value       = aws_cloudwatch_log_group.access.name
}
