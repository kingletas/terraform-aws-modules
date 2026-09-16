# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name       = "plan-test"
  subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
}

run "names_the_final_snapshot_even_when_skipped" {
  command = plan

  variables {
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_redshift_cluster.this.final_snapshot_identifier == "plan-test-final"
    error_message = "The final snapshot identifier must be set whether or not the snapshot is skipped."
  }
}

run "requires_ssl_whatever_the_parameters_are" {
  command = plan

  variables {
    parameters = {}
  }

  assert {
    condition     = contains([for parameter in aws_redshift_parameter_group.this.parameter : parameter.value if parameter.name == "require_ssl"], "true")
    error_message = "require_ssl must be set in the cluster's parameter group even with no other parameters."
  }

  assert {
    condition     = aws_redshift_cluster.this.cluster_parameter_group_name == "plan-test-params"
    error_message = "The cluster must use the module's parameter group, not the default one."
  }
}

run "refuses_require_ssl_in_parameters" {
  command = plan

  variables {
    parameters = { require_ssl = "false" }
  }

  expect_failures = [var.parameters]
}
