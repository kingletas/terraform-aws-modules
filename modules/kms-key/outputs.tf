output "arn" {
  description = "ARN of the key, which is what most resources want."
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "ID of the key."
  value       = aws_kms_key.this.key_id
}

output "alias_name" {
  description = "Primary alias, including the alias/ prefix."
  value       = aws_kms_alias.this.name
}

output "alias_arn" {
  description = "ARN of the primary alias."
  value       = aws_kms_alias.this.arn
}
