output "sftp_endpoint" {
  description = "Host name partners connect to. Give this to them with their username."
  value       = module.sftp.endpoint
}

output "host_key_fingerprint" {
  description = "Fingerprint of the server host key. Partners should verify this on first connect."
  value       = module.sftp.host_key_fingerprint
}

output "bucket" {
  description = "Bucket holding the exchanged files, one prefix per partner."
  value       = module.exchange.id
}

output "partner_prefixes" {
  description = "Where each partner's files land, keyed by username."
  value       = { for username in keys(var.partners) : username => format("s3://%s/%s/", module.exchange.id, username) }
}

output "log_group_name" {
  description = "CloudWatch log group recording every transfer."
  value       = module.sftp.log_group_name
}
