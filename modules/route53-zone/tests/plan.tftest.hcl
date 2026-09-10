# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name          = "example.com"
    records       = { www = { name = "www.example.com", type = "A", alias_name = "d111111abcdef8.cloudfront.net", alias_zone_id = "Z2FDTNDATAQYW2" } }
    health_checks = { web = { fqdn = "www.example.com" } }
  }
}
