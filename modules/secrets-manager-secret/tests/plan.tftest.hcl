# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "random" {}

variables {
  name = "plan-test/app/database"
}

run "creates_no_version_by_default" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 0
    error_message = "A secret with no initial value must not create a version."
  }
}

run "creates_a_version_from_a_value" {
  command = plan

  variables {
    initial_version = { value = "plan-test-placeholder" }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 1
    error_message = "An initial_version must create exactly one version."
  }
}

run "creates_a_json_version" {
  command = plan

  variables {
    initial_version = { json = { username = "app", password = "plan-test-placeholder" } }
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 1
    error_message = "A JSON initial_version must create exactly one version."
  }
}

run "refuses_value_and_json_together" {
  command = plan

  variables {
    initial_version = { value = "a", json = { b = "c" } }
  }

  expect_failures = [var.initial_version]
}

run "refuses_a_value_and_a_generated_password" {
  command = plan

  variables {
    initial_version   = { value = "plan-test-placeholder" }
    generate_password = true
  }

  expect_failures = [aws_secretsmanager_secret.this]
}

run "writes_a_write_only_version" {
  command = plan

  variables {
    secret_string_wo         = "plan-test-placeholder"
    secret_string_wo_version = 1
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 1
    error_message = "A write-only value with a version must create exactly one version."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.this[0].secret_string == null
    error_message = "A write-only version must not also carry the value in secret_string."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.this[0].secret_string_wo_version == 1
    error_message = "The write-only version number must reach the resource."
  }
}

run "writes_nothing_without_a_write_only_version" {
  command = plan

  variables {
    secret_string_wo = "plan-test-placeholder"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.this) == 0
    error_message = "A write-only value with no version must not create a version."
  }
}

run "refuses_a_write_only_value_and_an_initial_version" {
  command = plan

  variables {
    initial_version          = { value = "plan-test-placeholder" }
    secret_string_wo         = "plan-test-placeholder"
    secret_string_wo_version = 1
  }

  expect_failures = [aws_secretsmanager_secret.this]
}

run "refuses_a_fractional_write_only_version" {
  command = plan

  variables {
    secret_string_wo_version = 1.5
  }

  expect_failures = [var.secret_string_wo_version]
}
