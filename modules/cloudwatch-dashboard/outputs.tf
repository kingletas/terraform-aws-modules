output "name" {
  description = "Name of the dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "arn" {
  description = "ARN of the dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_arn
}

output "url" {
  description = "Console URL for the dashboard."
  value       = format("https://%s.console.aws.amazon.com/cloudwatch/home?region=%s#dashboards:name=%s", local.region, local.region, var.name)
}
