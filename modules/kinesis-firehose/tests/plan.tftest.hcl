# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  role_arn = "arn:aws:iam::123456789012:role/firehose-delivery"
}

run "plans_an_s3_stream" {
  command = plan

  variables {
    name = "plan-test-s3"

    s3_destination = {
      bucket_arn          = "arn:aws:s3:::plan-test-landing"
      prefix              = "raw/"
      error_output_prefix = "errors/"
    }

    log_group_name = "/aws/kinesisfirehose/plan-test-s3"
    tags           = { ManagedBy = "terraform" }
  }

  assert {
    condition     = aws_kinesis_firehose_delivery_stream.this.destination == "extended_s3"
    error_message = "An s3_destination must build an extended_s3 stream."
  }
}

run "plans_an_http_endpoint_stream" {
  command = plan

  variables {
    name = "plan-test-http"

    http_endpoint_destination = {
      url               = "https://aws-kinesis-http-intake.example.com/v1/input"
      name              = "metrics-vendor"
      access_key        = "plan-test-placeholder-value"
      backup_bucket_arn = "arn:aws:s3:::plan-test-backup"
      common_attributes = { environment = "plan-test" }
    }

    log_group_name = "/aws/kinesisfirehose/plan-test-http"
  }

  assert {
    condition     = aws_kinesis_firehose_delivery_stream.this.destination == "http_endpoint"
    error_message = "An http_endpoint_destination must build an http_endpoint stream."
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_no_destination" {
  command = plan

  variables {
    name = "plan-test"
  }

  expect_failures = [aws_kinesis_firehose_delivery_stream.this]
}

run "refuses_two_destinations" {
  command = plan

  variables {
    name           = "plan-test"
    s3_destination = { bucket_arn = "arn:aws:s3:::plan-test-landing" }

    http_endpoint_destination = {
      url               = "https://aws-kinesis-http-intake.example.com/v1/input"
      name              = "metrics-vendor"
      backup_bucket_arn = "arn:aws:s3:::plan-test-backup"
    }
  }

  expect_failures = [aws_kinesis_firehose_delivery_stream.this]
}

run "refuses_a_plaintext_endpoint" {
  command = plan

  variables {
    name = "plan-test"

    http_endpoint_destination = {
      url               = "http://aws-kinesis-http-intake.example.com/v1/input"
      name              = "metrics-vendor"
      backup_bucket_arn = "arn:aws:s3:::plan-test-backup"
    }
  }

  expect_failures = [var.http_endpoint_destination]
}
