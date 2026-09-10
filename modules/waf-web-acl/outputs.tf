output "arn" {
  description = "ARN of the web ACL. A CloudFront distribution takes this as web_acl_id."
  value       = aws_wafv2_web_acl.this.arn
}

output "id" {
  description = "ID of the web ACL."
  value       = aws_wafv2_web_acl.this.id
}

output "name" {
  description = "Name of the web ACL."
  value       = aws_wafv2_web_acl.this.name
}

output "capacity" {
  description = "Capacity units the rules consume. A web ACL is capped at 5000, so this is what limits how many rules fit."
  value       = aws_wafv2_web_acl.this.capacity
}
