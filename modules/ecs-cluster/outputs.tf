output "id" {
  description = "ID of the cluster."
  value       = aws_ecs_cluster.this.id
}

output "arn" {
  description = "ARN of the cluster."
  value       = aws_ecs_cluster.this.arn
}

output "name" {
  description = "Name of the cluster."
  value       = aws_ecs_cluster.this.name
}

output "exec_log_group_name" {
  description = "Log group holding ECS Exec session records, or null when exec logging is not overridden."
  value       = local.log_exec ? aws_cloudwatch_log_group.exec[0].name : null
}
