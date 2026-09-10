# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    parameters = { "/plan/test/level" = { description = "log level" }, "/plan/test/secret" = { type = "SecureString" } }
    values     = { "/plan/test/level" = "info", "/plan/test/secret" = "not-a-real-secret" }
  }
}
