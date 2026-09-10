output "id" {
  description = "ID of the file system, which is what a mount command names."
  value       = aws_efs_file_system.this.id
}

output "arn" {
  description = "ARN of the file system."
  value       = aws_efs_file_system.this.arn
}

output "dns_name" {
  description = "DNS name of the file system, resolvable from inside the VPC."
  value       = aws_efs_file_system.this.dns_name
}

output "mount_target_ids" {
  description = "Mount target IDs, keyed by availability zone."
  value       = { for zone, target in aws_efs_mount_target.this : zone => target.id }
}

output "mount_target_ips" {
  description = "Mount target IP addresses, keyed by availability zone."
  value       = { for zone, target in aws_efs_mount_target.this : zone => target.ip_address }
}

output "access_point_arns" {
  description = "Access point ARNs, keyed by the name you gave each one."
  value       = { for name, point in aws_efs_access_point.this : name => point.arn }
}
