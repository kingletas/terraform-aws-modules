# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name       = "plan-test"
  subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  instances  = { writer = {}, reader = {} }
}

run "monitors_every_instance_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role.monitoring) == 1
    error_message = "Enhanced monitoring must create one monitoring role."
  }

  assert {
    condition     = alltrue([for instance in aws_rds_cluster_instance.this : instance.monitoring_interval == 60])
    error_message = "Every instance must use the default 60-second monitoring interval."
  }

  assert {
    condition     = aws_rds_cluster.this.final_snapshot_identifier == "plan-test-final"
    error_message = "The final snapshot name must be stable so a later destroy can use it."
  }
}

run "turns_monitoring_off" {
  command = plan

  variables {
    monitoring_interval = 0
  }

  assert {
    condition     = length(aws_iam_role.monitoring) == 0
    error_message = "A zero interval must create no monitoring role."
  }

  assert {
    condition     = alltrue([for instance in aws_rds_cluster_instance.this : instance.monitoring_interval == 0])
    error_message = "A zero interval must turn monitoring off on every instance."
  }
}

run "keeps_a_final_snapshot_name_when_skipping" {
  command = plan

  variables {
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_rds_cluster.this.final_snapshot_identifier == "plan-test-final"
    error_message = "The final snapshot name must be set even while snapshots are skipped."
  }
}

run "refuses_an_unsupported_interval" {
  command = plan

  variables {
    monitoring_interval = 45
  }

  expect_failures = [var.monitoring_interval]
}
