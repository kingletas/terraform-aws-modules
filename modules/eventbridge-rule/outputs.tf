output "arn" {
  description = "ARN of the rule, which a Lambda permission uses as its source_arn."
  value       = aws_cloudwatch_event_rule.this.arn
}

output "name" {
  description = "Name of the rule."
  value       = aws_cloudwatch_event_rule.this.name
}

output "target_ids" {
  description = "Target IDs, keyed by the name you gave each one."
  value       = { for name, target in aws_cloudwatch_event_target.this : name => target.target_id }
}
