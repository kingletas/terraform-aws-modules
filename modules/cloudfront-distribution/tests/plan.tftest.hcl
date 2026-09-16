# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  comment           = "plan test"
  origins           = { app = { domain_name = "origin.example.com" } }
  default_origin    = "app"
  default_behaviour = { cache_policy_id = "plan-test-default-policy" }
}

run "orders_behaviours_by_precedence" {
  command = plan

  variables {
    ordered_behaviours = {
      aaa_last   = { path_pattern = "/*.css", origin = "app", precedence = 30, cache_policy_id = "plan-test-own-policy" }
      zzz_first  = { path_pattern = "/static/*", origin = "app", precedence = 5, cache_policy_id = "plan-test-own-policy" }
      bbb_second = { path_pattern = "/media/*", origin = "app", precedence = 10, cache_policy_id = "plan-test-own-policy" }
      aaa_second = { path_pattern = "/api/*", origin = "app", precedence = 10, cache_policy_id = "plan-test-own-policy" }
    }
  }

  assert {
    condition = [for behaviour in aws_cloudfront_distribution.this.ordered_cache_behavior : behaviour.path_pattern] == [
      "/static/*", "/api/*", "/media/*", "/*.css",
    ]
    error_message = "Ordered behaviours must follow precedence, with name as the tie-break."
  }
}

run "sends_each_behaviours_own_cache_policy" {
  command = plan

  variables {
    ordered_behaviours = {
      api = { path_pattern = "/api/*", origin = "app", precedence = 2, cache_policy_id = "plan-test-own-policy" }
    }
  }

  assert {
    condition     = aws_cloudfront_distribution.this.default_cache_behavior[0].cache_policy_id == "plan-test-default-policy"
    error_message = "The default behaviour must use the caller's cache policy."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[0].cache_policy_id == "plan-test-own-policy"
    error_message = "An ordered behaviour must use its own cache policy."
  }
}

run "refuses_a_default_behaviour_without_a_cache_policy" {
  command = plan

  variables {
    default_behaviour = {}
  }

  expect_failures = [var.default_behaviour]
}

run "refuses_an_ordered_behaviour_without_a_cache_policy" {
  command = plan

  variables {
    ordered_behaviours = {
      media = { path_pattern = "/media/*", origin = "app", precedence = 1 }
    }
  }

  expect_failures = [var.ordered_behaviours]
}

run "refuses_a_fractional_precedence" {
  command = plan

  variables {
    ordered_behaviours = {
      media = { path_pattern = "/media/*", origin = "app", precedence = 1.5, cache_policy_id = "plan-test-own-policy" }
    }
  }

  expect_failures = [var.ordered_behaviours]
}
