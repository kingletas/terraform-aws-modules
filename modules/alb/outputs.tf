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
  description = "ARN of the HTTPS listener, or null when create_https_listener is off."
  value       = local.https_enabled ? aws_lb_listener.https[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener, or null when create_http_listener is off."
  value       = var.create_http_listener ? aws_lb_listener.http[0].arn : null
}

output "https_listener_default_action" {
  description = "What the HTTPS listener does with a request no rule matches: type is forward or fixed-response, and status_code is the fixed response's status, else null. Null when create_https_listener is off."
  value = local.https_enabled ? {
    type        = aws_lb_listener.https[0].default_action[0].type
    status_code = try(tonumber(aws_lb_listener.https[0].default_action[0].fixed_response[0].status_code), null)
  } : null
}

output "listener_rules" {
  description = "Listener rules keyed by name: priority, action type, target group key, and the host, path and header names each rule matches on. Header values are left out because they are often a shared secret."
  value = {
    for name, rule in aws_lb_listener_rule.this : name => {
      priority      = rule.priority
      action        = rule.action[0].type
      target_group  = var.listener_rules[name].target_group
      host_headers  = toset(flatten([for condition in rule.condition : [for match in condition.host_header : match.values]]))
      path_patterns = toset(flatten([for condition in rule.condition : [for match in condition.path_pattern : match.values]]))
      http_headers  = toset(flatten([for condition in rule.condition : [for match in condition.http_header : match.http_header_name]]))
    }
  }
}
