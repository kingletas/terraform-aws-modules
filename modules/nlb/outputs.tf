output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "dns_name" {
  description = "DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone ID, for a Route 53 alias record."
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

output "listener_arns" {
  description = "Listener ARNs, keyed by the name you gave each one."
  value       = { for name, listener in aws_lb_listener.this : name => listener.arn }
}
