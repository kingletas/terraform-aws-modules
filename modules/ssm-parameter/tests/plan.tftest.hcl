# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    parameters  = { "/plan/test/level" = { description = "log level" }, "/plan/test/secret" = { type = "SecureString" } }
    values      = { "/plan/test/level" = "info", "/plan/test/secret" = "not-a-real-secret" }
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_ssm_parameter.this["/plan/test/level"].type == "String" && aws_ssm_parameter.this["/plan/test/level"].tier == "Standard"
    error_message = "A parameter should default to a Standard String."
  }

  assert {
    condition     = aws_ssm_parameter.this["/plan/test/secret"].type == "SecureString" && aws_ssm_parameter.this["/plan/test/secret"].key_id == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    error_message = "A SecureString parameter should be encrypted with the given key."
  }

  assert {
    condition     = nonsensitive(aws_ssm_parameter.this["/plan/test/level"].value) == "info" && aws_ssm_parameter.this["/plan/test/level"].overwrite == false
    error_message = "Each parameter should take its value by path, and not overwrite an existing one unless asked."
  }
}

run "refuses_a_parameter_with_no_value" {
  command = plan

  variables {
    parameters = { "/plan/test/level" = { description = "log level" }, "/plan/test/secret" = { type = "SecureString" } }
    values     = { "/plan/test/level" = "info" }
  }

  expect_failures = [var.values]
}
