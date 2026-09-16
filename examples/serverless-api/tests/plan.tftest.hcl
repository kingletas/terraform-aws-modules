# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    lambda_bucket = "artifacts-example"
  }

  assert {
    condition     = local.route_authorization == "NONE"
    error_message = "The example's routes are public by design and must say so."
  }

  assert {
    condition     = local.function_tracing_mode == "Active" && contains(values(local.function_managed_policies), "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess")
    error_message = "Active tracing needs X-Ray write access on the function role."
  }
}

run "plans_with_account_logging_role" {
  command = plan

  variables {
    lambda_bucket                   = "artifacts-example"
    manage_api_gateway_account_role = true
  }
}
