output "id" {
  description = "ID of the Client VPN endpoint."
  value       = aws_ec2_client_vpn_endpoint.this.id
}

output "arn" {
  description = "ARN of the Client VPN endpoint."
  value       = aws_ec2_client_vpn_endpoint.this.arn
}

output "dns_name" {
  description = "DNS name clients connect to. Prefix it with a random string when the endpoint has multiple associations."
  value       = aws_ec2_client_vpn_endpoint.this.dns_name
}

output "self_service_portal_url" {
  description = "Self-service portal URL, or null when the portal is disabled."
  value       = var.self_service_portal_enabled ? aws_ec2_client_vpn_endpoint.this.self_service_portal_url : null
}

output "server_certificate_arn" {
  description = "ACM ARN of the server certificate in use."
  value       = local.server_certificate_arn
}

output "client_root_certificate_chain_arn" {
  description = "ACM ARN of the client certificate authority, or null for non-certificate authentication."
  value       = local.client_root_certificate_chain_arn
}

output "network_association_ids" {
  description = "Network association IDs, keyed by availability zone."
  value       = { for zone, association in aws_ec2_client_vpn_network_association.this : zone => association.id }
}

output "connection_log_group_name" {
  description = "CloudWatch log group holding connection logs, or null when logging is disabled."
  value       = local.logging_enabled ? aws_cloudwatch_log_group.this[0].name : null
}
