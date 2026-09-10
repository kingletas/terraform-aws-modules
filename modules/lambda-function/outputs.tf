output "arn" {
  description = "ARN of the function."
  value       = aws_lambda_function.this.arn
}

output "name" {
  description = "Name of the function."
  value       = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  description = "ARN used by API Gateway and EventBridge to invoke the function, which is not the same as its ARN."
  value       = aws_lambda_function.this.invoke_arn
}

output "version" {
  description = "Published version, or $LATEST when publishing is off."
  value       = aws_lambda_function.this.version
}

output "qualified_arn" {
  description = "ARN including the version qualifier."
  value       = aws_lambda_function.this.qualified_arn
}

output "log_group_name" {
  description = "CloudWatch log group holding the function's logs."
  value       = aws_cloudwatch_log_group.this.name
}

output "event_source_mapping_uuids" {
  description = "Event source mapping UUIDs, keyed by the name you gave each one."
  value       = { for name, mapping in aws_lambda_event_source_mapping.this : name => mapping.uuid }
}
