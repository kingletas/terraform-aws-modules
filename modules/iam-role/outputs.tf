output "arn" {
  description = "ARN of the role."
  value       = aws_iam_role.this.arn
}

output "name" {
  description = "Generated name of the role."
  value       = aws_iam_role.this.name
}

output "id" {
  description = "ID of the role, which is the same as its name."
  value       = aws_iam_role.this.id
}

output "unique_id" {
  description = "Stable unique ID, which does not change if the role is renamed."
  value       = aws_iam_role.this.unique_id
}

output "instance_profile_name" {
  description = "Instance profile name, or null when none was created."
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null
}

output "instance_profile_arn" {
  description = "Instance profile ARN, or null when none was created."
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : null
}
