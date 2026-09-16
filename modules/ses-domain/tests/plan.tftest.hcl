# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    domain              = "example.com"
    mail_from_subdomain = "mail"
    dmarc_policy        = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"

    event_destinations = {
      bounces = {
        matching_event_types = ["BOUNCE", "COMPLAINT", "REJECT"]
        sns_topic_arn        = "arn:aws:sns:us-east-1:123456789012:email-problems"
      }
      metrics = {
        matching_event_types  = ["SEND", "DELIVERY", "DELIVERY_DELAY"]
        cloudwatch_dimensions = { message_type = { default_value = "transactional" } }
      }
    }

    tags = { ManagedBy = "terraform" }
  }

  assert {
    condition     = output.smtp_endpoint == "email-smtp.us-east-1.amazonaws.com"
    error_message = "The SMTP endpoint must be built from the region the module is planned in."
  }

  assert {
    condition     = output.mail_from_domain == "mail.example.com"
    error_message = "The MAIL FROM domain must be the subdomain joined to the identity domain."
  }

  assert {
    condition     = output.smtp_username == null
    error_message = "No SMTP user should exist unless one was asked for."
  }
}

run "plans_with_an_smtp_user_and_published_records" {
  command = plan

  variables {
    domain              = "example.com"
    mail_from_subdomain = "mail"
    create_dns_records  = true
    zone_id             = "Z0123456789ABCDEFGHIJ"
    create_smtp_user    = true
  }
}

# The quiet direction above proves nothing about the loud one.
run "refuses_publishing_records_with_no_zone" {
  command = plan

  variables {
    domain             = "example.com"
    create_dns_records = true
  }

  expect_failures = [aws_sesv2_email_identity.this]
}

run "refuses_a_mail_from_that_is_a_whole_domain" {
  command = plan

  variables {
    domain              = "example.com"
    mail_from_subdomain = "mail.example.com"
  }

  expect_failures = [var.mail_from_subdomain]
}

run "refuses_an_event_destination_with_two_targets" {
  command = plan

  variables {
    domain = "example.com"

    event_destinations = {
      both = {
        matching_event_types  = ["BOUNCE"]
        sns_topic_arn         = "arn:aws:sns:us-east-1:123456789012:email-problems"
        cloudwatch_dimensions = { message_type = { default_value = "transactional" } }
      }
    }
  }

  expect_failures = [var.event_destinations]
}

run "refuses_an_event_type_ses_does_not_publish" {
  command = plan

  variables {
    domain = "example.com"

    event_destinations = {
      typo = {
        matching_event_types = ["BOUNCED"]
        sns_topic_arn        = "arn:aws:sns:us-east-1:123456789012:email-problems"
      }
    }
  }

  expect_failures = [var.event_destinations]
}
