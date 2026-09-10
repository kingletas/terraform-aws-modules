output "id" {
  description = "Identifier of the instance."
  value       = aws_db_instance.this.id
}

output "arn" {
  description = "ARN of the instance."
  value       = aws_db_instance.this.arn
}

output "endpoint" {
  description = "Host and port to connect to."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the instance, without the port."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the instance listens on."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the database created on first boot."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the master password, or null when the password is managed by hand."
  value       = var.manage_master_password ? aws_db_instance.this.master_user_secret[0].secret_arn : null
}

output "subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}
