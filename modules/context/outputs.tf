output "prefix" {
  description = "Name prefix, as project-environment-component. Most resources take this."
  value       = local.prefix
}

output "short_prefix" {
  description = "The prefix truncated to 24 characters, for names AWS caps at 32 with a suffix."
  value       = local.short
}

output "compact_prefix" {
  description = "The prefix with hyphens removed, for names that reject them such as a CloudWatch metric namespace."
  value       = local.compact_name
}

output "tags" {
  description = "Tags every resource in this project should carry. Production also gets Backup = true, which is what a tag-selected backup plan picks up."
  value       = local.tags
}

output "is_production" {
  description = "Whether production guards apply. Use it rather than comparing the environment string again."
  value       = local.is_production
}

output "defaults" {
  description = "Environment-appropriate defaults: multi_az, deletion_protection, skip_final_snapshot, backup_retention_days, log_retention_days, single_nat_gateway, min_capacity, desired_capacity and max_capacity."
  value       = local.defaults[var.environment]
}

output "name" {
  description = "Function-style helper: a map from suffix to full name for a handful of common suffixes."
  value = {
    for suffix in ["vpc", "alb", "web", "app", "data", "cache", "search", "queue", "bastion", "cron", "admin", "builder"] :
    suffix => format("%s-%s", local.prefix, suffix)
  }
}
