# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    url        = "https://token.actions.githubusercontent.com"
    client_ids = ["sts.amazonaws.com"]
    tags       = { ManagedBy = "terraform" }
  }

  assert {
    condition     = output.audience_key == "token.actions.githubusercontent.com:aud"
    error_message = "The audience key must be the issuer host, not the URL."
  }

  assert {
    condition     = output.subject_key == "token.actions.githubusercontent.com:sub"
    error_message = "The subject key must be the issuer host, not the URL."
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_a_trailing_slash" {
  command = plan

  variables {
    url        = "https://token.actions.githubusercontent.com/"
    client_ids = ["sts.amazonaws.com"]
  }

  expect_failures = [var.url]
}

run "refuses_a_provider_with_no_audience" {
  command = plan

  variables {
    url        = "https://token.actions.githubusercontent.com"
    client_ids = []
  }

  expect_failures = [var.client_ids]
}

run "refuses_a_thumbprint_that_is_not_a_sha1" {
  command = plan

  variables {
    url         = "https://oidc.example.com"
    client_ids  = ["sts.amazonaws.com"]
    thumbprints = ["not-a-thumbprint"]
  }

  expect_failures = [var.thumbprints]
}
