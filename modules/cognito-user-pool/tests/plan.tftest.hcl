# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name          = "plan-test"
    domain_prefix = "plan-test-login"
    clients       = { web = { callback_urls = ["https://app.example.com/callback"] } }
  }
}
