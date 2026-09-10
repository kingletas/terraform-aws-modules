output "name" {
  description = "Name of the log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "arn" {
  description = "ARN of the log group, with the :* suffix AWS appends."
  value       = aws_cloudwatch_log_group.this.arn
}

output "metric_filter_ids" {
  description = "Metric filter IDs, keyed by the name you gave each one."
  value       = { for name, filter in aws_cloudwatch_log_metric_filter.this : name => filter.id }
}
