output "id" {
  description = "Identifier of the policy."
  value       = aws_organizations_policy.this.id
}

output "arn" {
  description = "ARN of the policy."
  value       = aws_organizations_policy.this.arn
}

output "name" {
  description = "Name of the policy."
  value       = aws_organizations_policy.this.name
}

output "attachment_target_ids" {
  description = "What the policy is attached to, keyed the way the targets were declared."
  value       = { for key, attachment in aws_organizations_policy_attachment.this : key => attachment.target_id }
}
