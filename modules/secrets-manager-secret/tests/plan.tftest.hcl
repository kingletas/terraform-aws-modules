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
