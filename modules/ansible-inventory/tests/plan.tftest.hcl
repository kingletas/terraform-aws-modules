# Plans the module on its own with plainly fake values. Nothing is created or written.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name           = "plan-test"
  output_dir     = "plan-test-output"
  regions        = ["us-east-1"]
  discovery_tags = { Project = "plan-test" }
}

run "names_hosts_by_instance_id" {
  command = plan

  assert {
    condition     = local.inventory_config.hostnames[0] == "instance-id"
    error_message = "Hosts should be named by instance ID, since autoscaled instances share a Name tag."
  }

  assert {
    condition     = !contains(keys(local.inventory_config.compose), "ansible_aws_ssm_bucket_name")
    error_message = "No SSM bucket should be written when none was given."
  }
}

run "writes_the_ssm_bucket_into_the_connection" {
  command = plan

  variables {
    ssm_bucket_name = "plan-test-ssm-transfer"
  }

  assert {
    condition     = local.inventory_config.compose["ansible_aws_ssm_bucket_name"] == "'plan-test-ssm-transfer'"
    error_message = "The SSM bucket should be written into the connection variables."
  }
}

run "connects_over_ssh_by_private_address" {
  command = plan

  variables {
    connection      = "ssh"
    ssm_bucket_name = "plan-test-ssm-transfer"
  }

  assert {
    condition     = local.inventory_config.compose["ansible_host"] == "private_ip_address" && !contains(keys(local.inventory_config.compose), "ansible_aws_ssm_bucket_name")
    error_message = "An ssh connection should use the private address and carry no SSM settings."
  }
}

run "merges_the_facts_lookup_into_the_callers_all_group" {
  command = plan

  variables {
    facts      = { db_host = "db.plan-test.invalid" }
    group_vars = { all = { app_env = "plan-test" }, web = { serves_http = "true" } }
  }

  assert {
    condition     = keys(local_file.group_vars) == ["all", "web"]
    error_message = "One all.yml should be written, not a second resource competing for the same file."
  }

  assert {
    condition     = keys(yamldecode(local.group_var_files["all"])) == ["app_env", "terraform_facts"]
    error_message = "all.yml should carry both the caller's variables and the facts lookup."
  }
}

run "writes_all_for_facts_alone" {
  command = plan

  variables {
    facts = { db_host = "db.plan-test.invalid" }
  }

  assert {
    condition     = keys(yamldecode(local.group_var_files["all"])) == ["terraform_facts"]
    error_message = "With facts and no group_vars, all.yml should hold the lookup."
  }
}

run "refuses_terraform_facts_in_the_all_group" {
  command = plan

  variables {
    group_vars = { all = { terraform_facts = "plan-test" } }
  }

  expect_failures = [var.group_vars]
}
