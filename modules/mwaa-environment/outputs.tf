output "arn" {
  description = "ARN of the environment."
  value       = aws_mwaa_environment.this.arn
}

output "name" {
  description = "Name of the environment."
  value       = aws_mwaa_environment.this.name
}

output "webserver_url" {
  description = "Airflow UI. Reachable only from inside the VPC when access mode is PRIVATE_ONLY."
  value       = aws_mwaa_environment.this.webserver_url
}

output "status" {
  description = "Environment status. Creation takes 20 to 30 minutes."
  value       = aws_mwaa_environment.this.status
}

output "service_role_arn" {
  description = "Service-linked role MWAA created for itself."
  value       = aws_mwaa_environment.this.service_role_arn
}

output "logging_group_arns" {
  description = "CloudWatch log groups MWAA writes to, keyed by log type."
  value = {
    dag_processing = try(aws_mwaa_environment.this.logging_configuration[0].dag_processing_logs[0].cloud_watch_log_group_arn, null)
    scheduler      = try(aws_mwaa_environment.this.logging_configuration[0].scheduler_logs[0].cloud_watch_log_group_arn, null)
    task           = try(aws_mwaa_environment.this.logging_configuration[0].task_logs[0].cloud_watch_log_group_arn, null)
    webserver      = try(aws_mwaa_environment.this.logging_configuration[0].webserver_logs[0].cloud_watch_log_group_arn, null)
    worker         = try(aws_mwaa_environment.this.logging_configuration[0].worker_logs[0].cloud_watch_log_group_arn, null)
  }
}
