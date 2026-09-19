output "storefront_url" {
  description = "Where the storefront answers."
  value       = format("https://%s", var.domain_name)
}

output "environment" {
  description = "Which environment this is, and therefore which defaults applied."
  value       = var.environment
}

output "applied_defaults" {
  description = "The environment-dependent settings the context module chose: multi-AZ, retention, capacity and guards."
  value       = local.defaults
}

output "cdn_distribution_id" {
  description = "Distribution ID, which an invalidation command needs after a deploy."
  value       = module.cdn.id
}

output "origin_dns_name" {
  description = "The load balancer behind CloudFront. It accepts only CloudFront origin-facing addresses and answers 403 without the origin verify header."
  value       = aws_route53_record.origin.fqdn
}

output "web_autoscaling_group" {
  description = "Name of the web tier autoscaling group."
  value       = module.web.name
}

output "singleton_instance_ids" {
  description = "The nodes that are not replaceable, keyed by role."
  value       = module.singletons.instance_ids_by_role
}

output "database_endpoint" {
  description = "Aurora writer endpoint."
  value       = module.database.endpoint
}

output "database_secret_arn" {
  description = "Secrets Manager secret holding the database password. Nothing readable is in Terraform state."
  value       = module.database.master_user_secret_arn
}

output "service_credential_parameters" {
  description = "SSM SecureString parameters holding the Valkey auth token and the OpenSearch master password: the path of each, keyed by the short name the configuration uses. The parameter values are not in any output."
  value       = module.service_credentials.names
}

output "ansible_inventory" {
  description = "Dynamic inventory configuration. It discovers hosts by tag, so it stays correct as the web tier scales."
  value       = module.ansible.inventory_path
}

output "ansible_facts_parameter" {
  description = "SSM parameter every playbook and every node reads its endpoints from."
  value       = module.ansible.facts_parameter_name
}

output "configure_command" {
  description = "What to run to configure whatever is currently running."
  value       = module.ansible.ansible_command
}

output "session_command" {
  description = "How to get a shell on a node, with no key and nothing open inbound."
  value       = "aws ssm start-session --target <instance-id>"
}

output "dashboard_url" {
  description = "CloudWatch dashboard for the storefront."
  value       = module.dashboard.url
}
