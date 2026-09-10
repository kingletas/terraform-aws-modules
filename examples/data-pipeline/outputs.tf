output "raw_bucket" {
  description = "Bucket holding raw extracts, exactly as they arrived."
  value       = module.raw.id
}

output "curated_bucket" {
  description = "Bucket holding curated datasets."
  value       = module.curated.id
}

output "extract_state_machine_arn" {
  description = "ARN of the extraction state machine."
  value       = module.extract.arn
}

output "transform_state_machine_arn" {
  description = "ARN of the transform state machine."
  value       = module.transform.arn
}

output "source_secret_arns" {
  description = "Empty secrets awaiting a password, keyed by source name."
  value       = { for name, secret in module.source_credentials : name => secret.arn }
}

output "run_ledger_table" {
  description = "DynamoDB table recording each run."
  value       = module.run_ledger.name
}

output "populate_secrets_commands" {
  description = "What to run once, per source, to write a password without it passing through Terraform."
  value = {
    for name, secret in module.source_credentials : name =>
    format("aws secretsmanager put-secret-value --secret-id %s --secret-string '{\"username\":\"%s\",\"password\":\"REPLACE\"}'", secret.arn, var.sources[name].username)
  }
}
