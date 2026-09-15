output "arn" {
  description = "ARN of the provider. This is the provider_arn an iam-role trust takes."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "url" {
  description = "Issuer URL, as registered."
  value       = aws_iam_openid_connect_provider.this.url
}

output "host" {
  description = "Issuer host, which is what the condition keys are built from."
  value       = local.host
}

output "audience_key" {
  description = "Condition key holding the aud claim, ready for an iam-role trust."
  value       = format("%s:aud", local.host)
}

output "subject_key" {
  description = "Condition key holding the sub claim, which is what narrows a trust to one repository, branch or environment."
  value       = format("%s:sub", local.host)
}
