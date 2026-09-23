output "instances" {
  description = "Every instance, keyed by name, with the fields a downstream inventory or ssh config needs."
  value = {
    for key, instance in aws_instance.this : local.instances[key].name => {
      id                = instance.id
      arn               = instance.arn
      role              = instance.tags.Role
      private_ip        = instance.private_ip
      private_dns       = instance.private_dns
      public_ip         = try(aws_eip.this[key].public_ip, instance.public_ip)
      availability_zone = instance.availability_zone
      subnet_id         = instance.subnet_id
    }
  }
}

output "by_role" {
  description = "Instance names grouped by role, so a caller can address a whole tier without filtering."
  value = {
    for role in distinct([for name, instance in local.instances : instance.role]) :
    role => sort([for key, instance in local.instances : instance.name if instance.role == role])
  }
}

output "private_ips_by_role" {
  description = "Private addresses grouped by role."
  value = {
    for role in distinct([for name, instance in local.instances : instance.role]) :
    role => [for key, instance in local.instances : aws_instance.this[key].private_ip if instance.role == role]
  }
}

output "instance_ids" {
  description = "Instance IDs, keyed by name."
  value       = { for key, instance in aws_instance.this : local.instances[key].name => instance.id }
}

output "instance_ids_by_role" {
  description = "Instance IDs grouped by role, which is what an SSM run command targets."
  value = {
    for role in distinct([for name, instance in local.instances : instance.role]) :
    role => [for key, instance in local.instances : aws_instance.this[key].id if instance.role == role]
  }
}

output "elastic_ips" {
  description = "Elastic IPs, keyed by instance name. Empty for roles that did not ask for one."
  value       = { for key, address in aws_eip.this : local.instances[key].name => address.public_ip }
}

output "roles" {
  description = "Role names in the fleet."
  value       = sort(distinct([for name, instance in local.instances : instance.role]))
}
