output "connection_id" {
  description = "ID of the VPN connection."
  value       = aws_vpn_connection.this.id
}

output "customer_gateway_id" {
  description = "ID of the customer gateway."
  value       = aws_customer_gateway.this.id
}

output "vpn_gateway_id" {
  description = "ID of the virtual private gateway, or null when attached to a transit gateway."
  value       = local.create_vgw ? aws_vpn_gateway.this[0].id : null
}

output "tunnel_addresses" {
  description = "Public addresses of the two AWS-side tunnel endpoints. The far side's device points at these."
  value = [
    aws_vpn_connection.this.tunnel1_address,
    aws_vpn_connection.this.tunnel2_address,
  ]
}

output "tunnel_inside_cidrs" {
  description = "Inside address ranges of each tunnel."
  value = [
    aws_vpn_connection.this.tunnel1_inside_cidr,
    aws_vpn_connection.this.tunnel2_inside_cidr,
  ]
}

output "customer_gateway_configuration" {
  description = "Device configuration for the far side, including the pre-shared keys. Hand it over out of band."
  value       = aws_vpn_connection.this.customer_gateway_configuration
  sensitive   = true
}

output "transit_gateway_attachment_id" {
  description = "Transit gateway attachment ID, or null when attached to a virtual private gateway."
  value       = aws_vpn_connection.this.transit_gateway_attachment_id
}
