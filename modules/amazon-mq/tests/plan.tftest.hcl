# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  # Plainly fake, and long enough to satisfy the length rule under test.
  users = { app = { password = "plan-test-placeholder-value" } }
}

run "plans_a_rabbitmq_cluster" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"

    deployment_mode    = "CLUSTER_MULTI_AZ"
    host_instance_type = "mq.m5.large"
    subnet_ids         = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    security_group_ids = ["sg-0ccccccccccccccc3"]

    maintenance_window = { day_of_week = "SUNDAY", time_of_day = "04:00" }

    tags = { ManagedBy = "terraform" }
  }
}

run "plans_an_activemq_pair_with_a_configuration" {
  command = plan

  variables {
    name           = "plan-test-activemq"
    engine_type    = "ActiveMQ"
    engine_version = "5.18"

    deployment_mode = "ACTIVE_STANDBY_MULTI_AZ"
    storage_type    = "efs"
    subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]

    audit_log_enabled = true

    users = {
      app     = { password = "plan-test-placeholder-value" }
      console = { password = "plan-test-placeholder-value", console_access = true, groups = ["admin"] }
    }

    configuration = {
      data        = "<broker xmlns=\"http://activemq.apache.org/schema/core\"></broker>"
      description = "Plan test only."
    }
  }
}

# Refusal tests: each run below must fail the plan. Every rule here
# is one AWS would otherwise refuse at apply, after part of a stack exists.
run "refuses_an_activemq_deployment_mode_on_rabbitmq" {
  command = plan

  variables {
    name            = "plan-test"
    engine_version  = "3.13"
    deployment_mode = "ACTIVE_STANDBY_MULTI_AZ"
    subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  }

  expect_failures = [aws_mq_broker.this]
}

run "refuses_a_multi_az_broker_in_one_subnet" {
  command = plan

  variables {
    name            = "plan-test"
    engine_version  = "3.13"
    deployment_mode = "CLUSTER_MULTI_AZ"
    subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1"]
  }

  expect_failures = [aws_mq_broker.this]
}

run "refuses_a_second_rabbitmq_user" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]

    users = {
      app   = { password = "plan-test-placeholder-value" }
      other = { password = "plan-test-placeholder-value" }
    }
  }

  expect_failures = [aws_mq_broker.this]
}

run "refuses_an_audit_log_on_rabbitmq" {
  command = plan

  variables {
    name              = "plan-test"
    engine_version    = "3.13"
    subnet_ids        = ["subnet-0aaaaaaaaaaaaaaa1"]
    audit_log_enabled = true
  }

  expect_failures = [aws_mq_broker.this]
}

run "refuses_efs_storage_on_rabbitmq" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    storage_type   = "efs"
  }

  expect_failures = [aws_mq_broker.this]
}

run "refuses_a_password_that_is_too_short" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    users          = { app = { password = "short" } }
  }

  expect_failures = [var.users]
}

run "refuses_a_password_with_too_few_different_characters" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    users          = { app = { password = "abcabcabcabcabc" } }
  }

  expect_failures = [var.users]
}

run "refuses_a_password_with_a_colon" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    users          = { app = { password = "plan-test:placeholder" } }
  }

  expect_failures = [var.users]
}

run "refuses_a_password_with_an_equals_sign" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    users          = { app = { password = "plan-test=placeholder" } }
  }

  expect_failures = [var.users]
}

run "plans_a_customer_managed_key_on_activemq" {
  command = plan

  variables {
    name           = "plan-test-activemq"
    engine_type    = "ActiveMQ"
    engine_version = "5.18"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = one(aws_mq_broker.this.encryption_options).use_aws_owned_key == false
    error_message = "A customer managed key must turn off the AWS-owned key."
  }
}

run "refuses_a_customer_managed_key_on_rabbitmq" {
  command = plan

  variables {
    name           = "plan-test"
    engine_version = "3.13"
    subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1"]
    kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [aws_mq_broker.this]
}
