output "transit_gateway_id" {
  description = "ID of the transit gateway."
  value       = module.transit.id
}

output "shared_vpc_id" {
  description = "ID of the shared services VPC."
  value       = module.shared_vpc.vpc_id
}

output "spoke_vpc_ids" {
  description = "Spoke VPC IDs, keyed by spoke name."
  value       = { for name, vpc in module.spoke_vpcs : name => vpc.vpc_id }
}

output "route_table_ids" {
  description = "Transit gateway route table IDs, keyed by name."
  value       = module.transit.route_table_ids
}

output "nat_public_ips" {
  description = "Addresses every spoke appears from. This is the allow-list a partner asks for."
  value       = module.shared_vpc.nat_public_ips
}

output "vpn_tunnel_addresses" {
  description = "AWS-side tunnel endpoints the on-premises device points at."
  value       = var.on_premises == null ? [] : module.on_premises[0].tunnel_addresses
}

output "vpn_configuration" {
  description = "Device configuration for the far side, including pre-shared keys. Hand it over out of band."
  value       = var.on_premises == null ? null : module.on_premises[0].customer_gateway_configuration
  sensitive   = true
}
