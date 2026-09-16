output "replication_instance_arn" {
  description = "ARN of the replication instance."
  value       = aws_dms_replication_instance.this.replication_instance_arn
}

output "replication_instance_id" {
  description = "Identifier of the replication instance."
  value       = aws_dms_replication_instance.this.replication_instance_id
}

output "private_ip_addresses" {
  description = "Addresses the instance connects from. This is what a source system's firewall allow-lists."
  value       = aws_dms_replication_instance.this.replication_instance_private_ips
}

output "public_ip_addresses" {
  description = "Public addresses, empty unless the instance is publicly accessible."
  value       = aws_dms_replication_instance.this.replication_instance_public_ips
}

output "endpoint_arns" {
  description = "Endpoint ARNs, keyed by the name you gave each one."
  value       = { for name, endpoint in aws_dms_endpoint.this : name => endpoint.endpoint_arn }
}

output "task_arns" {
  description = "Replication task ARNs, keyed by the name you gave each one."
  value       = { for name, task in aws_dms_replication_task.this : name => task.replication_task_arn }
}

output "subnet_group_id" {
  description = "ID of the replication subnet group."
  value       = aws_dms_replication_subnet_group.this.id
}

output "service_role_arns" {
  description = "ARNs of the account-level roles this module created, keyed dms_vpc and dms_cloudwatch_logs when create_service_roles is on, and dms_access_for_endpoint when create_endpoint_access_role is on."
  value = merge(
    var.create_service_roles ? {
      dms_vpc             = aws_iam_role.dms_vpc[0].arn
      dms_cloudwatch_logs = aws_iam_role.dms_cloudwatch_logs[0].arn
    } : {},
    var.create_endpoint_access_role ? {
      dms_access_for_endpoint = aws_iam_role.dms_access_for_endpoint[0].arn
    } : {},
  )
}
