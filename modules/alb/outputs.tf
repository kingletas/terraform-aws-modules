output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "DNS name of the load balancer. Point an alias record at this, never a CNAME to an IP."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone ID of the load balancer, for a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "arn_suffix" {
  description = "ARN suffix, which is what CloudWatch metric dimensions use."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arns" {
  description = "Target group ARNs, keyed by the name you gave each one."
  value       = { for name, group in aws_lb_target_group.this : name => group.arn }
}

output "target_group_arn_suffixes" {
  description = "Target group ARN suffixes, for CloudWatch metric dimensions."
  value       = { for name, group in aws_lb_target_group.this : name => group.arn_suffix }
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, or null when no certificate was given."
  value       = local.https_enabled ? aws_lb_listener.https[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}
