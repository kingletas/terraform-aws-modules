output "id" {
  description = "ID of the service."
  value       = aws_ecs_service.this.id
}

output "name" {
  description = "Name of the service."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN of the task definition revision the service is running."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family name."
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Revision number of the task definition."
  value       = aws_ecs_task_definition.this.revision
}

output "log_group_name" {
  description = "CloudWatch log group holding container logs."
  value       = aws_cloudwatch_log_group.this.name
}

output "autoscaling_target_resource_id" {
  description = "Application autoscaling resource ID, or null when autoscaling is off."
  value       = local.scaling == null ? null : aws_appautoscaling_target.this[0].resource_id
}
