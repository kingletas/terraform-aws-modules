output "arn" {
  description = "ARN of the certificate. Use validated_arn where something must not attach before issuance."
  value       = aws_acm_certificate.this.arn
}

output "validated_arn" {
  description = "ARN that only resolves once the certificate is issued, so a listener cannot attach to a pending one."
  value       = local.manage_validation_records && var.wait_for_validation ? aws_acm_certificate_validation.this[0].certificate_arn : aws_acm_certificate.this.arn
}

output "domain_name" {
  description = "Primary domain on the certificate."
  value       = aws_acm_certificate.this.domain_name
}

output "status" {
  description = "Issuance status of the certificate."
  value       = aws_acm_certificate.this.status
}

output "validation_records" {
  description = "DNS records proving domain control, keyed by domain. Give these to whoever runs the zone when it is not in Route 53."
  value = {
    for option in aws_acm_certificate.this.domain_validation_options :
    option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  }
}
