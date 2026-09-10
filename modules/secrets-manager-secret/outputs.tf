output "arn" {
  description = "ARN of the secret, which is what an IAM policy and an ECS task definition reference."
  value       = aws_secretsmanager_secret.this.arn
}

output "id" {
  description = "ID of the secret."
  value       = aws_secretsmanager_secret.this.id
}

output "name" {
  description = "Name of the secret."
  value       = aws_secretsmanager_secret.this.name
}

output "version_id" {
  description = "Version ID of the first version, or null when none was written."
  value       = local.has_initial_version ? aws_secretsmanager_secret_version.this[0].version_id : null
}

output "replica_regions" {
  description = "Regions the secret is replicated to."
  value       = keys(var.replica_regions)
}
