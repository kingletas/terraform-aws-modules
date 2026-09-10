output "id" {
  description = "ID of the transfer server."
  value       = aws_transfer_server.this.id
}

output "arn" {
  description = "ARN of the transfer server."
  value       = aws_transfer_server.this.arn
}

output "endpoint" {
  description = "Host name partners connect to."
  value       = aws_transfer_server.this.endpoint
}

output "host_key_fingerprint" {
  description = "Fingerprint of the server host key. Give it to partners so they can verify what they are connecting to."
  value       = aws_transfer_server.this.host_key_fingerprint
}

output "user_role_arns" {
  description = "Per-user IAM role ARNs, keyed by username."
  value       = { for username, role in aws_iam_role.user : username => role.arn }
}

output "log_group_name" {
  description = "CloudWatch log group holding transfer records."
  value       = aws_cloudwatch_log_group.this.name
}
