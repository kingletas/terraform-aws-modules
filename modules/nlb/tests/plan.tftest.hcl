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

run "names_target_groups_within_limits" {
  command = plan

  variables {
    name       = "a-network-load-balancer-32-chars"
    vpc_id     = "vpc-0123456789abcdef0"
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1"]
    target_groups = {
      postgres          = { port = 5432, target_type = "ip" }
      "postgres_reader" = { port = 5433, target_type = "ip" }
    }
    listeners = { app = { port = 5432, target_group = "postgres" } }
  }

  assert {
    condition = alltrue([
      for tg_name in values(local.target_group_names) :
      length(tg_name) <= 32 && can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", tg_name))
    ])
    error_message = "Every target group name must be at most 32 characters of alphanumerics and hyphens, with no hyphen at either end."
  }

  assert {
    condition     = local.target_group_names["postgres"] != local.target_group_names["postgres_reader"]
    error_message = "Two target groups sharing a truncated prefix must still get different names."
  }
}
