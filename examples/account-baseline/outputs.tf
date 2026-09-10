output "trail_arn" {
  description = "ARN of the audit trail."
  value       = module.trail.arn
}

output "trail_bucket" {
  description = "Bucket holding trail log files."
  value       = module.trail_bucket.id
}

output "trail_log_group" {
  description = "CloudWatch log group holding the queryable copy."
  value       = module.trail_logs.name
}

output "security_topic_arn" {
  description = "SNS topic security alarms publish to."
  value       = module.security_alerts.arn
}

output "dashboard_url" {
  description = "Security dashboard. Every panel should normally read zero."
  value       = module.security_dashboard.url
}

output "backup_vault_name" {
  description = "Backup vault holding recovery points."
  value       = module.backups.vault_name
}

output "backup_tag" {
  description = "Tag a resource with this to have it backed up."
  value       = format("%s = %s", var.backup_selection_tag.key, var.backup_selection_tag.value)
}
