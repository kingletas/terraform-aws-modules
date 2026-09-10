output "name" {
  description = "Generated name of the autoscaling group."
  value       = aws_autoscaling_group.this.name
}

output "arn" {
  description = "ARN of the autoscaling group."
  value       = aws_autoscaling_group.this.arn
}

output "id" {
  description = "ID of the autoscaling group, which is the same as its name."
  value       = aws_autoscaling_group.this.id
}

output "availability_zones" {
  description = "Availability zones the group launches into."
  value       = aws_autoscaling_group.this.availability_zones
}

output "scaling_policy_arns" {
  description = "Scaling policy ARNs, keyed by the name you gave each one."
  value       = { for name, policy in aws_autoscaling_policy.target_tracking : name => policy.arn }
}
