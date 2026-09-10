output "account_id" {
  description = "Account these settings apply to."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Region the regional settings apply to."
  value       = coalesce(var.region_name, data.aws_region.current.region)
}

output "ebs_encryption_by_default" {
  description = "Whether new EBS volumes in this region are encrypted regardless of what asked for them."
  value       = aws_ebs_encryption_by_default.this.enabled
}

output "s3_public_access_blocked" {
  description = "Whether public access is blocked account-wide."
  value       = var.block_s3_public_access
}

output "locked_default_security_group_ids" {
  description = "Default security groups emptied by this module, keyed by the name given to each VPC."
  value       = { for name, group in aws_default_security_group.this : name => group.id }
}
