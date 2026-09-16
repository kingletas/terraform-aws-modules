output "plan_id" {
  description = "ID of the backup plan."
  value       = aws_backup_plan.this.id
}

output "plan_arn" {
  description = "ARN of the backup plan."
  value       = aws_backup_plan.this.arn
}

output "vault_name" {
  description = "Name of the backup vault."
  value       = aws_backup_vault.this.name
}

output "vault_arn" {
  description = "ARN of the backup vault, which a cross-region copy target references."
  value       = aws_backup_vault.this.arn
}

output "role_arn" {
  description = "ARN of the role Backup assumes to take and restore backups."
  value       = aws_iam_role.this.arn
}

output "role_policy_arns" {
  description = "Managed policy ARNs attached to the backup role."
  value = concat(
    [aws_iam_role_policy_attachment.backup.policy_arn, aws_iam_role_policy_attachment.restore.policy_arn],
    var.s3_backup_enabled ? [aws_iam_role_policy_attachment.s3_backup[0].policy_arn, aws_iam_role_policy_attachment.s3_restore[0].policy_arn] : [],
  )
}

output "selection_id" {
  description = "ID of the resource selection, or null when nothing was selected."
  value       = local.has_selection ? aws_backup_selection.this[0].id : null
}
