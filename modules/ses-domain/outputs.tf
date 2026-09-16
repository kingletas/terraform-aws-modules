output "arn" {
  description = "ARN of the email identity."
  value       = aws_sesv2_email_identity.this.arn
}

output "domain" {
  description = "Domain that was verified."
  value       = aws_sesv2_email_identity.this.email_identity
}

output "verified" {
  description = "Whether SES has seen the DNS records and verified the identity. False until they resolve."
  value       = aws_sesv2_email_identity.this.verified_for_sending_status
}

output "configuration_set_name" {
  description = "Configuration set every send through this identity is attributed to."
  value       = aws_sesv2_configuration_set.this.configuration_set_name
}

output "mail_from_domain" {
  description = "Envelope sender domain, or null when the AWS default is in use."
  value       = local.mail_from_domain
}

output "dns_records" {
  description = "Every record the domain needs, whether or not this module published them. With byodkim set, the DKIM TXT record is not listed and is yours to publish. Give these to whoever runs the zone when it is not in Route 53."
  value = concat(
    [
      for token in(local.easy_dkim ? aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens : []) : {
        name  = format("%s._domainkey.%s", token, var.domain)
        type  = "CNAME"
        value = format("%s.dkim.amazonses.com", token)
      }
    ],
    local.mail_from_domain == null ? [] : [
      {
        name  = local.mail_from_domain
        type  = "MX"
        value = format("10 feedback-smtp.%s.amazonses.com", data.aws_region.current.region)
      },
      {
        name  = local.mail_from_domain
        type  = "TXT"
        value = "v=spf1 include:amazonses.com ~all"
      },
    ],
    var.dmarc_policy == null ? [] : [
      {
        name  = format("_dmarc.%s", var.domain)
        type  = "TXT"
        value = var.dmarc_policy
      },
    ],
  )
}

output "smtp_endpoint" {
  description = "SMTP host for this region. Port 587 with STARTTLS, or 465 with implicit TLS."
  value       = format("email-smtp.%s.%s", data.aws_region.current.region, data.aws_partition.current.dns_suffix)
}

output "smtp_username" {
  description = "SMTP username, which is the access key ID. Null when create_smtp_user is false."
  value       = var.create_smtp_user ? aws_iam_access_key.smtp[0].id : null
}

output "smtp_password" {
  description = "SMTP password, derived from the secret access key. Null when create_smtp_user is false."
  value       = var.create_smtp_user ? aws_iam_access_key.smtp[0].ses_smtp_password_v4 : null
  sensitive   = true
}
