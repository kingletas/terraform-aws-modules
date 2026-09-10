# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    on_premises = { gateway_ip = "203.0.113.10", static_routes_only = true, routes = ["192.168.0.0/16"] }
  }
}
