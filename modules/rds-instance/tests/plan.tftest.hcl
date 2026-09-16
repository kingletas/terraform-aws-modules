# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name                   = "plan-test"
    subnet_ids             = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    parameters             = { log_min_duration_statement = "500" }
    parameter_group_family = "postgres16"
  }
}

run "names_the_final_snapshot_even_when_skipped" {
  command = plan

  variables {
    name                = "plan-test"
    subnet_ids          = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "plan-test-final"
    error_message = "The final snapshot identifier must be set whether or not the snapshot is skipped."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.monitoring[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
    error_message = "The monitoring policy ARN must be built from the current partition."
  }
}
