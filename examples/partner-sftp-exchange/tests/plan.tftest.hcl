# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    partners         = { acme = { public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlanTestOnlyNotARealKeyAtAll plan-test"] } }
    notify_on_upload = true
  }
}
