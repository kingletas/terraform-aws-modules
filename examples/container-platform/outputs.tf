output "service_url" {
  description = "Where the platform answers."
  value       = format("https://%s", var.domain_name)
}

output "repository_urls" {
  description = "Push targets, keyed by service name. This is what a build tags against."
  value       = { for name, repository in module.repositories : name => repository.repository_url }
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.cluster.name
}

output "service_names" {
  description = "ECS service names, keyed by service."
  value       = { for name, service in module.services : name => service.name }
}

output "task_definition_arns" {
  description = "Task definition ARNs currently deployed, keyed by service."
  value       = { for name, service in module.services : name => service.task_definition_arn }
}

output "database_writer_endpoint" {
  description = "Aurora writer endpoint."
  value       = module.database.endpoint
}

output "database_secret_arn" {
  description = "Secrets Manager secret holding the database credentials."
  value       = module.database.master_user_secret_arn
}

output "log_group_names" {
  description = "CloudWatch log groups holding container logs, keyed by service."
  value       = { for name, service in module.services : name => service.log_group_name }
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}
