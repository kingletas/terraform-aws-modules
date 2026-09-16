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

run "defaults_to_essentials_with_threat_protection_off" {
  command = plan

  variables {
    name = "plan-test"
  }

  assert {
    condition     = aws_cognito_user_pool.this.user_pool_tier == "ESSENTIALS" && one(aws_cognito_user_pool.this.user_pool_add_ons).advanced_security_mode == "OFF"
    error_message = "A new pool should be on ESSENTIALS with threat protection off."
  }
}

run "plans_threat_protection_on_plus" {
  command = plan

  variables {
    name                   = "plan-test"
    user_pool_tier         = "PLUS"
    advanced_security_mode = "ENFORCED"
  }
}

run "refuses_threat_protection_without_plus" {
  command = plan

  variables {
    name                   = "plan-test"
    advanced_security_mode = "AUDIT"
  }

  expect_failures = [aws_cognito_user_pool.this]
}
