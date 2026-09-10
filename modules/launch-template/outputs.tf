output "id" {
  description = "ID of the launch template."
  value       = aws_launch_template.this.id
}

output "arn" {
  description = "ARN of the launch template."
  value       = aws_launch_template.this.arn
}

output "name" {
  description = "Generated name of the launch template."
  value       = aws_launch_template.this.name
}

output "latest_version" {
  description = "Newest version number. An autoscaling group pointed at this follows every change."
  value       = aws_launch_template.this.latest_version
}
