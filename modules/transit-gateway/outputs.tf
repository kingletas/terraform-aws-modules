output "id" {
  description = "ID of the transit gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "arn" {
  description = "ARN of the transit gateway."
  value       = aws_ec2_transit_gateway.this.arn
}

output "association_default_route_table_id" {
  description = "Default association route table, used by attachments that name no table of their own."
  value       = aws_ec2_transit_gateway.this.association_default_route_table_id
}

output "route_table_ids" {
  description = "Route table IDs, keyed by the name you gave each one."
  value       = { for name, table in aws_ec2_transit_gateway_route_table.this : name => table.id }
}

output "vpc_attachment_ids" {
  description = "VPC attachment IDs, keyed by the name you gave each one."
  value       = { for name, attachment in aws_ec2_transit_gateway_vpc_attachment.this : name => attachment.id }
}

output "resource_share_arn" {
  description = "Resource Access Manager share ARN, or null when the gateway is not shared."
  value       = length(var.share_with_principals) > 0 ? aws_ram_resource_share.this[0].arn : null
}
