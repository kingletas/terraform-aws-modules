output "cluster_identifier" {
  description = "Identifier of the cluster."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "arn" {
  description = "ARN of the cluster."
  value       = aws_rds_cluster.this.arn
}

output "endpoint" {
  description = "Writer endpoint. Send everything that writes here."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint, load balanced across every reader instance."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "Port the cluster listens on."
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Name of the database created on first boot."
  value       = aws_rds_cluster.this.database_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the master password, or null when the password is managed by hand."
  value       = var.manage_master_password ? aws_rds_cluster.this.master_user_secret[0].secret_arn : null
}

output "instance_endpoints" {
  description = "Per-instance endpoints, keyed by the name you gave each one."
  value       = { for name, instance in aws_rds_cluster_instance.this : name => instance.endpoint }
}
