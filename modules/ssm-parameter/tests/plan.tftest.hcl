# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    path_prefix = "/plan/test"
    parameters  = { level = { description = "log level" }, "nested/secret" = { type = "SecureString" } }
    values      = { level = "info", "nested/secret" = "not-a-real-secret" }
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_ssm_parameter.this["level"].type == "String" && aws_ssm_parameter.this["level"].tier == "Standard"
    error_message = "A parameter should default to a Standard String."
  }

  assert {
    condition     = aws_ssm_parameter.this["nested/secret"].type == "SecureString" && aws_ssm_parameter.this["nested/secret"].key_id == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    error_message = "A SecureString parameter should be encrypted with the given key."
  }

  # The short key is the address; the full path is what AWS is asked for.
  assert {
    condition     = aws_ssm_parameter.this["level"].name == "/plan/test/level" && aws_ssm_parameter.this["nested/secret"].name == "/plan/test/nested/secret"
    error_message = "Each parameter's path should be the prefix followed by its name."
  }

  assert {
    condition     = aws_ssm_parameter.this["level"].tags["Name"] == "/plan/test/level"
    error_message = "A parameter should be tagged with its full path."
  }

  assert {
    condition     = nonsensitive(aws_ssm_parameter.this["level"].value) == "info" && aws_ssm_parameter.this["level"].overwrite == false
    error_message = "Each parameter should take its value by name, and not overwrite an existing one unless asked."
  }
}

run "plans_at_the_root_of_the_hierarchy" {
  command = plan

  variables {
    parameters = { "log-level" = {} }
    values     = { "log-level" = "info" }
  }

  assert {
    condition     = aws_ssm_parameter.this["log-level"].name == "/log-level"
    error_message = "With no prefix a parameter should sit at the root of the hierarchy."
  }
}

run "refuses_a_parameter_with_no_value" {
  command = plan

  variables {
    parameters = { level = { description = "log level" }, secret = { type = "SecureString" } }
    values     = { level = "info" }
  }

  expect_failures = [var.values]
}

run "refuses_a_name_that_is_a_full_path" {
  command = plan

  variables {
    path_prefix = "/plan/test"
    parameters  = { "/plan/test/level" = {} }
    values      = { "/plan/test/level" = "info" }
  }

  expect_failures = [var.parameters]
}

run "refuses_a_prefix_that_ends_in_a_slash" {
  command = plan

  variables {
    path_prefix = "/plan/test/"
    parameters  = { level = {} }
    values      = { level = "info" }
  }

  expect_failures = [var.path_prefix]
}
