# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name          = "plan-test"
    vpc_id        = "vpc-0123456789abcdef0"
    subnet_ids    = ["subnet-0aaaaaaaaaaaaaaa1"]
    target_groups = { app = { port = 5432, target_type = "ip" } }
    listeners     = { app = { port = 5432, target_group = "app" } }
  }
}
