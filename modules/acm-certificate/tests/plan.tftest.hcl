# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  domain_name = "example.com"
}

run "waits_for_issuance_when_records_are_written_elsewhere" {
  command = plan

  variables {
    create_validation_records = false
  }

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 1
    error_message = "validated_arn must wait for issuance even when this module writes no records."
  }

  assert {
    condition     = aws_acm_certificate_validation.this[0].validation_record_fqdns == null
    error_message = "Without records here, the wait must not name any record FQDNs."
  }
}

run "does_not_wait_when_told_not_to" {
  command = plan

  variables {
    create_validation_records = false
    wait_for_validation       = false
  }

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 0
    error_message = "With wait_for_validation off there is nothing to wait on."
  }
}
