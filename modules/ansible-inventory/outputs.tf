output "inventory_path" {
  description = "Path of the generated dynamic inventory configuration. It holds no addresses, so it is safe to commit."
  value       = local_file.inventory.filename
}

output "facts_parameter_name" {
  description = "SSM parameter holding the facts, or null when none were supplied."
  value       = length(var.facts) > 0 ? aws_ssm_parameter.facts[0].name : null
}

output "facts_parameter_arn" {
  description = "ARN of the facts parameter, for the IAM policy that lets a host or a runner read it."
  value       = length(var.facts) > 0 ? aws_ssm_parameter.facts[0].arn : null
}

output "group_var_paths" {
  description = "Generated group_vars files, keyed by group name."
  value       = { for group, file in local_file.group_vars : group => file.filename }
}

output "discovery_tags" {
  description = "Tags a host must carry to appear in this inventory. An instance without them is invisible to it."
  value       = var.discovery_tags
}

output "ansible_command" {
  description = "What to run to apply a playbook against the discovered hosts."
  value       = format("ansible-playbook -i %s playbook.yml", local_file.inventory.filename)
}

output "ssh_proxy_command" {
  description = "ProxyCommand for reaching an instance over Systems Manager, for a person rather than a playbook. Null when the connection is plain ssh."
  value       = var.connection == "ssm" ? "sh -c \"aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p\"" : null
}
