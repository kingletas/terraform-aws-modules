output "cluster_identifier" {
  description = "Identifier of the cluster."
  value       = aws_docdb_cluster.this.cluster_identifier
}

output "arn" {
  description = "ARN of the cluster."
  value       = aws_docdb_cluster.this.arn
}

output "endpoint" {
  description = "Writer endpoint."
  value       = aws_docdb_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint, load balanced across replicas."
  value       = aws_docdb_cluster.this.reader_endpoint
}

output "port" {
  description = "Port the cluster listens on."
  value       = aws_docdb_cluster.this.port
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the master password, or null when the password is managed by hand."
  value       = var.manage_master_password ? aws_docdb_cluster.this.master_user_secret[0].secret_arn : null
}

output "instance_endpoints" {
  description = "Per-instance endpoints, in creation order."
  value       = aws_docdb_cluster_instance.this[*].endpoint
}
