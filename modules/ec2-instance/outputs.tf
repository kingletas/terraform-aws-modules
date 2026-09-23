output "instance_ids" {
  description = "Instance IDs, keyed by instance name."
  value       = { for key, instance in aws_instance.this : local.instances[key].name => instance.id }
}

output "instance_arns" {
  description = "Instance ARNs, keyed by instance name."
  value       = { for key, instance in aws_instance.this : local.instances[key].name => instance.arn }
}

output "private_ips" {
  description = "Private IPv4 addresses, keyed by instance name."
  value       = { for key, instance in aws_instance.this : local.instances[key].name => instance.private_ip }
}

output "public_ips" {
  description = "Public IPv4 addresses, keyed by instance name. Empty unless public IPs were requested."
  value       = { for key, instance in aws_instance.this : local.instances[key].name => instance.public_ip if instance.public_ip != "" }
}

output "availability_zones" {
  description = "Availability zone each instance landed in, keyed by instance name."
  value       = { for key, instance in aws_instance.this : local.instances[key].name => instance.availability_zone }
}

output "volume_ids" {
  description = "Additional EBS volume IDs, keyed by instance name and volume name."
  value       = { for key, volume in aws_ebs_volume.this : local.volume_attachments[key].name => volume.id }
}
