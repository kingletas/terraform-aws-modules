# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "random" {}

run "plans_with_real_values" {
  command = plan

}
