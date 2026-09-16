# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  comment        = "plan test"
  origins        = { app = { domain_name = "origin.example.com" } }
  default_origin = "app"
}

run "orders_behaviours_by_precedence" {
  command = plan

  variables {
    ordered_behaviours = {
      aaa_last   = { path_pattern = "/*.css", origin = "app", precedence = 30 }
      zzz_first  = { path_pattern = "/static/*", origin = "app", precedence = 5 }
      bbb_second = { path_pattern = "/media/*", origin = "app", precedence = 10 }
      aaa_second = { path_pattern = "/api/*", origin = "app", precedence = 10 }
    }
  }

  assert {
    condition = [for behaviour in aws_cloudfront_distribution.this.ordered_cache_behavior : behaviour.path_pattern] == [
      "/static/*", "/api/*", "/media/*", "/*.css",
    ]
    error_message = "Ordered behaviours must follow precedence, with name as the tie-break."
  }
}

# The looked-up policy ID is not computed in the provider schema, so a mock leaves it
# null; this proves the lookup and that a caller's own policy wins.
run "looks_up_caching_optimized_and_keeps_a_callers_policy" {
  command = plan

  variables {
    ordered_behaviours = {
      media = { path_pattern = "/media/*", origin = "app", precedence = 1 }
      api   = { path_pattern = "/api/*", origin = "app", precedence = 2, cache_policy_id = "plan-test-own-policy" }
    }
  }

  assert {
    condition     = data.aws_cloudfront_cache_policy.caching_optimized.name == "Managed-CachingOptimized"
    error_message = "The fallback must be the Managed-CachingOptimized policy."
  }

  assert {
    condition     = aws_cloudfront_distribution.this.ordered_cache_behavior[1].cache_policy_id == "plan-test-own-policy"
    error_message = "A behaviour's own cache policy must win over the fallback."
  }
}

run "refuses_a_fractional_precedence" {
  command = plan

  variables {
    ordered_behaviours = {
      media = { path_pattern = "/media/*", origin = "app", precedence = 1.5 }
    }
  }

  expect_failures = [var.ordered_behaviours]
}
