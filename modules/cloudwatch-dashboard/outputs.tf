output "name" {
  description = "Name of the dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "arn" {
  description = "ARN of the dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_arn
}

output "url" {
  description = "Console URL for the dashboard, or null in a partition with no known console hostname."
  value       = local.console_host == null ? null : format("https://%s/cloudwatch/home?region=%s#dashboards:name=%s", local.console_host, local.region, var.name)
}
