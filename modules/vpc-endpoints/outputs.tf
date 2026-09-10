output "interface_endpoint_ids" {
  description = "Interface endpoint IDs, keyed by service short name."
  value       = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.id }
}

output "interface_dns_names" {
  description = "Private DNS names of each interface endpoint, keyed by service short name."
  value       = { for service, endpoint in aws_vpc_endpoint.interface : service => endpoint.dns_entry }
}

output "gateway_endpoint_ids" {
  description = "Gateway endpoint IDs, keyed by service short name."
  value       = { for service, endpoint in aws_vpc_endpoint.gateway : service => endpoint.id }
}

output "gateway_prefix_list_ids" {
  description = "Prefix list ID of each gateway endpoint, for use in a security group rule."
  value       = { for service, endpoint in aws_vpc_endpoint.gateway : service => endpoint.prefix_list_id }
}
