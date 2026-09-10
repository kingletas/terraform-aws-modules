output "arn" {
  description = "ARN of the state machine."
  value       = aws_sfn_state_machine.this.arn
}

output "name" {
  description = "Name of the state machine."
  value       = aws_sfn_state_machine.this.name
}

output "creation_date" {
  description = "When the state machine was created."
  value       = aws_sfn_state_machine.this.creation_date
}

output "log_group_name" {
  description = "CloudWatch log group holding execution logs, or null when logging is off."
  value       = local.logging_enabled ? aws_cloudwatch_log_group.this[0].name : null
}
