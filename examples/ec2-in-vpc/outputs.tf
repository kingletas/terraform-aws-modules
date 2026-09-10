output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "instance_ids" {
  description = "Instance IDs, keyed by instance name. Connect with: aws ssm start-session --target <id>"
  value       = module.app.instance_ids
}

output "private_ips" {
  description = "Private IPv4 addresses, keyed by instance name."
  value       = module.app.private_ips
}

output "nat_public_ips" {
  description = "Outbound addresses the instances appear from, for allow-listing downstream."
  value       = module.vpc.nat_public_ips
}
