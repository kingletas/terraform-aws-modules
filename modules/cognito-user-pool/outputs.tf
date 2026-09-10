output "id" {
  description = "ID of the user pool."
  value       = aws_cognito_user_pool.this.id
}

output "arn" {
  description = "ARN of the user pool, which an API Gateway authorizer references."
  value       = aws_cognito_user_pool.this.arn
}

output "endpoint" {
  description = "Token and JWKS endpoint host for the pool."
  value       = aws_cognito_user_pool.this.endpoint
}

output "domain" {
  description = "Hosted UI domain, or null when none was created."
  value       = local.create_domain ? aws_cognito_user_pool_domain.this[0].domain : null
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution behind a custom domain, which the A record must alias to."
  value       = local.create_domain && local.use_custom_domain ? aws_cognito_user_pool_domain.this[0].cloudfront_distribution_arn : null
}

output "client_ids" {
  description = "App client IDs, keyed by client name."
  value       = { for name, client in aws_cognito_user_pool_client.this : name => client.id }
}

output "client_secrets" {
  description = "App client secrets, keyed by client name. Only populated for clients that generate one."
  value       = { for name, client in aws_cognito_user_pool_client.this : name => client.client_secret }
  sensitive   = true
}
