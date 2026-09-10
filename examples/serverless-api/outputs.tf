output "api_url" {
  description = "Base URL of the deployed stage."
  value       = module.api.invoke_url
}

output "api_id" {
  description = "ID of the REST API."
  value       = module.api.id
}

output "table_name" {
  description = "DynamoDB table holding orders."
  value       = module.orders.name
}

output "work_queue_url" {
  description = "URL of the work queue."
  value       = module.work_queue.id
}

output "dead_letter_queue_url" {
  description = "URL of the dead letter queue. This is where a failed message ends up."
  value       = module.work_queue.dead_letter_queue_url
}

output "function_names" {
  description = "Lambda function names, keyed by the name you gave each one."
  value       = { for name, fn in module.functions : name => fn.name }
}

output "log_group_names" {
  description = "CloudWatch log groups, keyed by function name."
  value       = { for name, fn in module.functions : name => fn.log_group_name }
}
