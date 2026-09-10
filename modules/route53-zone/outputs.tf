output "zone_id" {
  description = "ID of the hosted zone."
  value       = aws_route53_zone.this.zone_id
}

output "arn" {
  description = "ARN of the hosted zone."
  value       = aws_route53_zone.this.arn
}

output "name" {
  description = "Domain name of the zone."
  value       = aws_route53_zone.this.name
}

output "name_servers" {
  description = "Name servers for the zone. Give these to the registrar, or a public zone answers for nobody."
  value       = aws_route53_zone.this.name_servers
}

output "record_fqdns" {
  description = "Fully qualified names of the records created, keyed by the name you gave each one."
  value       = { for name, record in aws_route53_record.this : name => record.fqdn }
}

output "health_check_ids" {
  description = "Health check IDs, keyed by the name you gave each one."
  value       = { for name, check in aws_route53_health_check.this : name => check.id }
}
