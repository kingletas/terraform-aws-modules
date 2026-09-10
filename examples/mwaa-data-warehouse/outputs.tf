output "airflow_webserver_url" {
  description = "Airflow UI. Reachable only from inside the VPC, since access mode is PRIVATE_ONLY."
  value       = module.airflow.webserver_url
}

output "dags_bucket" {
  description = "Bucket to sync DAG files into, under the dags/ prefix."
  value       = module.dags.id
}

output "warehouse_endpoint" {
  description = "Redshift endpoint."
  value       = module.warehouse.endpoint
}

output "warehouse_database" {
  description = "First database in the cluster."
  value       = module.warehouse.database_name
}

output "warehouse_secret_arn" {
  description = "Secrets Manager secret holding the Redshift master password."
  value       = module.warehouse.master_password_secret_arn
}

output "replication_instance_ips" {
  description = "Addresses DMS connects from. This is what a source system's firewall allow-lists."
  value       = module.replication.private_ip_addresses
}

output "replication_task_arns" {
  description = "Replication task ARNs, keyed by source name. Airflow starts these."
  value       = module.replication.task_arns
}

output "source_secret_arns" {
  description = "Empty secrets awaiting credentials, keyed by source name."
  value       = { for name, secret in module.source_secrets : name => secret.arn }
}

output "populate_secrets_commands" {
  description = "What to run once per endpoint, so no credential passes through Terraform."
  value = merge(
    {
      for name, secret in module.source_secrets : name =>
      format("aws secretsmanager put-secret-value --secret-id %s --secret-string '{\"username\":\"REPLACE\",\"password\":\"REPLACE\",\"host\":\"REPLACE\",\"port\":1433}'", secret.arn)
    },
    {
      warehouse = format("aws secretsmanager put-secret-value --secret-id %s --secret-string '{\"username\":\"%s\",\"password\":\"REPLACE\",\"host\":\"%s\",\"port\":%d}'", module.warehouse_secret.arn, module.warehouse.master_username, module.warehouse.dns_name, module.warehouse.port)
    }
  )
}
