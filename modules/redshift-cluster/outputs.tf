output "id" {
  description = "Identifier of the cluster."
  value       = aws_redshift_cluster.this.id
}

output "arn" {
  description = "ARN of the cluster."
  value       = aws_redshift_cluster.this.arn
}

output "endpoint" {
  description = "Host and port to connect to."
  value       = aws_redshift_cluster.this.endpoint
}

output "dns_name" {
  description = "Hostname of the cluster, without the port."
  value       = aws_redshift_cluster.this.dns_name
}

output "port" {
  description = "Port the cluster listens on."
  value       = aws_redshift_cluster.this.port
}

output "database_name" {
  description = "Name of the first database."
  value       = aws_redshift_cluster.this.database_name
}

output "master_username" {
  description = "Master username."
  value       = aws_redshift_cluster.this.master_username
}

output "master_password_secret_arn" {
  description = "Secrets Manager secret holding the master password, or null when the password is managed by hand."
  value       = var.manage_master_password ? aws_redshift_cluster.this.master_password_secret_arn : null
}

output "subnet_group_name" {
  description = "Name of the cluster subnet group."
  value       = aws_redshift_subnet_group.this.name
}
