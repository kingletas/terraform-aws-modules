# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name       = "plan-test"
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  }
}

run "keeps_audit_logging_on_when_the_caller_map_omits_it" {
  command = plan

  variables {
    name       = "plan-test"
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    parameters = { tls = "enabled" }
  }

  assert {
    condition     = local.parameters == { audit_logs = "enabled", tls = "enabled" }
    error_message = "A parameters map without audit_logs must still enable audit logging."
  }

  assert {
    condition     = { for parameter in aws_docdb_cluster_parameter_group.this.parameter : parameter.name => parameter.value } == { audit_logs = "enabled", tls = "enabled" }
    error_message = "The parameter group must carry audit_logs alongside the caller's parameters."
  }
}

run "keeps_audit_logging_on_with_an_empty_map" {
  command = plan

  variables {
    name       = "plan-test"
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    parameters = {}
  }

  assert {
    condition     = { for parameter in aws_docdb_cluster_parameter_group.this.parameter : parameter.name => parameter.value } == { audit_logs = "enabled" }
    error_message = "An empty parameters map must still create a parameter group with audit logging on."
  }
}

run "lets_the_caller_turn_audit_logging_off_explicitly" {
  command = plan

  variables {
    name       = "plan-test"
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    parameters = { tls = "enabled", audit_logs = "disabled" }
  }

  assert {
    condition     = local.parameters.audit_logs == "disabled"
    error_message = "An explicit audit_logs value must win over the module's default."
  }
}
