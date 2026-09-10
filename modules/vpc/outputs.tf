output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "cidr_block" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, keyed by availability zone."
  value       = { for zone, subnet in aws_subnet.public : zone => subnet.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs, keyed by availability zone."
  value       = { for zone, subnet in aws_subnet.private : zone => subnet.id }
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks, keyed by availability zone."
  value       = { for zone, subnet in aws_subnet.public : zone => subnet.cidr_block }
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks, keyed by availability zone."
  value       = { for zone, subnet in aws_subnet.private : zone => subnet.cidr_block }
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs, keyed by availability zone. Empty when NAT is disabled."
  value       = { for zone, gateway in aws_nat_gateway.this : zone => gateway.id }
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateways, for allow-listing outbound traffic downstream."
  value       = { for zone, address in aws_eip.nat : zone => address.public_ip }
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs, keyed by availability zone. A gateway endpoint needs these."
  value       = { for zone, table in aws_route_table.private : zone => table.id }
}

output "default_security_group_id" {
  description = "ID of the VPC default security group, which permits no traffic."
  value       = aws_default_security_group.this.id
}

output "flow_log_group_name" {
  description = "CloudWatch log group holding VPC flow logs, or null when flow logging is disabled."
  value       = local.flow_logs_enabled ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
