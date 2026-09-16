data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  mail_from_domain = var.mail_from_subdomain == null ? null : format("%s.%s", var.mail_from_subdomain, var.domain)

  # Whether a key was supplied is not secret, and for_each refuses a sensitive value.
  easy_dkim = nonsensitive(var.byodkim == null)

  # Easy DKIM publishes three CNAMEs, one per signing token, keyed by position because the tokens are unknown at plan.
  dkim_records = var.create_dns_records && local.easy_dkim ? {
    for index in range(3) :
    format("dkim-%d", index) => {
      name  = format("%s._domainkey.%s", aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens[index], var.domain)
      value = format("%s.dkim.amazonses.com", aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens[index])
    }
  } : {}

  arn_prefix            = format("arn:%s:ses:%s:%s", data.aws_partition.current.partition, data.aws_region.current.region, data.aws_caller_identity.current.account_id)
  identity_arn          = format("%s:identity/%s", local.arn_prefix, var.domain)
  configuration_set_arn = format("%s:configuration-set/%s", local.arn_prefix, aws_sesv2_configuration_set.this.configuration_set_name)

  smtp_user_name = coalesce(var.smtp_user_name, format("ses-smtp-%s", replace(var.domain, ".", "-")))

  tags = merge(var.tags, { Name = var.domain })
}

resource "aws_sesv2_email_identity" "this" {
  email_identity         = var.domain
  configuration_set_name = aws_sesv2_configuration_set.this.configuration_set_name

  dkim_signing_attributes {
    next_signing_key_length    = var.byodkim == null ? var.dkim_key_length : null
    domain_signing_private_key = try(var.byodkim.private_key, null)
    domain_signing_selector    = try(var.byodkim.selector, null)
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !var.create_dns_records || var.zone_id != null
      error_message = "Publishing records needs zone_id. Leave create_dns_records false and read the dns_records output instead."
    }

    precondition {
      condition     = var.byodkim == null || var.dkim_key_length == "RSA_2048_BIT"
      error_message = "dkim_key_length applies to Easy DKIM only. With byodkim set, the key length is whatever your key is."
    }
  }
}

resource "aws_sesv2_email_identity_mail_from_attributes" "this" {
  count = local.mail_from_domain == null ? 0 : 1

  email_identity         = aws_sesv2_email_identity.this.email_identity
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = var.behavior_on_mx_failure
}

resource "aws_sesv2_configuration_set" "this" {
  configuration_set_name = replace(var.domain, ".", "-")

  delivery_options {
    tls_policy = var.tls_policy
  }

  reputation_options {
    reputation_metrics_enabled = true
  }

  sending_options {
    sending_enabled = true
  }

  suppression_options {
    suppressed_reasons = var.suppressed_reasons
  }

  tags = local.tags
}

resource "aws_sesv2_configuration_set_event_destination" "this" {
  for_each = var.event_destinations

  configuration_set_name = aws_sesv2_configuration_set.this.configuration_set_name
  event_destination_name = each.key

  event_destination {
    enabled              = each.value.enabled
    matching_event_types = each.value.matching_event_types

    dynamic "sns_destination" {
      for_each = each.value.sns_topic_arn == null ? [] : [each.value.sns_topic_arn]

      content {
        topic_arn = sns_destination.value
      }
    }

    dynamic "cloud_watch_destination" {
      for_each = each.value.cloudwatch_dimensions == null ? [] : [each.value.cloudwatch_dimensions]

      content {
        dynamic "dimension_configuration" {
          for_each = cloud_watch_destination.value

          content {
            dimension_name          = dimension_configuration.key
            dimension_value_source  = dimension_configuration.value.source
            default_dimension_value = dimension_configuration.value.default_value
          }
        }
      }
    }
  }
}

resource "aws_route53_record" "dkim" {
  for_each = local.dkim_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CNAME"
  records = [each.value.value]
  ttl     = 600

  allow_overwrite = true
}

resource "aws_route53_record" "mail_from_mx" {
  count = var.create_dns_records && local.mail_from_domain != null ? 1 : 0

  zone_id = var.zone_id
  name    = local.mail_from_domain
  type    = "MX"
  records = [format("10 feedback-smtp.%s.amazonses.com", data.aws_region.current.region)]
  ttl     = 600

  allow_overwrite = true
}

resource "aws_route53_record" "mail_from_spf" {
  count = var.create_dns_records && local.mail_from_domain != null ? 1 : 0

  zone_id = var.zone_id
  name    = local.mail_from_domain
  type    = "TXT"
  records = ["v=spf1 include:amazonses.com ~all"]
  ttl     = 600

  allow_overwrite = true
}

resource "aws_route53_record" "dmarc" {
  count = var.create_dns_records && var.dmarc_policy != null ? 1 : 0

  zone_id = var.zone_id
  name    = format("_dmarc.%s", var.domain)
  type    = "TXT"
  records = [var.dmarc_policy]
  ttl     = 600

  allow_overwrite = true
}
