output "site_url" {
  description = "Where the site answers."
  value       = format("https://%s", var.domain_name)
}

output "distribution_id" {
  description = "Distribution ID, which an invalidation command needs."
  value       = module.cdn.id
}

output "distribution_domain_name" {
  description = "CloudFront domain name behind the alias records."
  value       = module.cdn.domain_name
}

output "content_bucket" {
  description = "Bucket a deploy syncs into."
  value       = module.content.id
}

output "logs_bucket" {
  description = "Bucket holding CloudFront access logs."
  value       = module.logs.id
}

output "invalidation_command" {
  description = "What to run after a deploy that changed index.html."
  value       = format("aws cloudfront create-invalidation --distribution-id %s --paths '/index.html' '/'", module.cdn.id)
}
