output "vpn_dns_name" {
  description = "DNS name to put in the client configuration file."
  value       = module.client_vpn.dns_name
}

output "vpn_endpoint_id" {
  description = "Endpoint ID, for exporting a client configuration with the AWS CLI."
  value       = module.client_vpn.id
}

output "vpc_id" {
  description = "ID of the VPC clients reach through the tunnel."
  value       = module.vpc.vpc_id
}

output "connection_log_group_name" {
  description = "CloudWatch log group holding connection logs."
  value       = module.client_vpn.connection_log_group_name
}
