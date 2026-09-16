# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    aws_service_access_principals = ["cloudtrail.amazonaws.com", "sso.amazonaws.com"]
    enabled_policy_types          = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]

    organizational_units = {
      platform = { children = { shared = {} } }
      workload = { children = { staging = {}, production = { tags = { Tier = "critical" } } } }
      sandbox  = {}
    }

    accounts = {
      logging    = { name = "logging", email = "aws+logging@example.com", parent = "platform/shared" }
      staging    = { name = "staging", email = "aws+staging@example.com", parent = "workload/staging" }
      production = { name = "production", email = "aws+production@example.com", parent = "workload/production", close_on_deletion = false }
      scratch    = { name = "scratch", email = "aws+scratch@example.com", parent = "sandbox" }
    }

    tags = { ManagedBy = "terraform" }
  }
}

# Refusal tests: each run below must fail the plan. An account naming
# an organizational unit that was never declared must stop the plan rather than
# land the account at the root.
run "refuses_an_account_in_an_unknown_unit" {
  command = plan

  variables {
    organizational_units = { workload = {} }

    accounts = {
      staging = { name = "staging", email = "aws+staging@example.com", parent = "workload/staging" }
    }
  }

  expect_failures = [aws_organizations_account.this]
}

run "refuses_policy_types_without_the_all_feature_set" {
  command = plan

  variables {
    feature_set          = "CONSOLIDATED_BILLING"
    enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  }

  expect_failures = [aws_organizations_organization.this]
}

run "refuses_an_account_with_no_email" {
  command = plan

  variables {
    accounts = {
      staging = { name = "staging", email = "not-an-address" }
    }
  }

  expect_failures = [var.accounts]
}

run "builds_member_role_arns_in_the_current_partition" {
  command = plan

  override_data {
    target = data.aws_partition.current
    values = { partition = "aws-us-gov" }
  }

  override_resource {
    target          = aws_organizations_account.this
    override_during = plan
    values          = { id = "210987654321" }
  }

  variables {
    accounts = {
      staging = { name = "staging", email = "aws+staging@example.com" }
    }
  }

  assert {
    condition     = output.account_role_arns["staging"] == "arn:aws-us-gov:iam::210987654321:role/OrganizationAccountAccessRole"
    error_message = "The member role ARN does not use the current partition."
  }
}
