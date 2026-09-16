# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name       = "plan-test"
  subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]

  secrets_access_role_arn = "arn:aws:iam::123456789012:role/plan-test-dms-secrets"

  endpoints = {
    source = {
      endpoint_type = "source"
      engine_name   = "postgres"
      database_name = "orders"
      secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:plan-test-source"
    }
    target = {
      endpoint_type = "target"
      engine_name   = "redshift"
      database_name = "warehouse"
      secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:plan-test-target"
    }
  }
}

run "plans_a_task_without_service_roles" {
  command = plan

  variables {
    tasks = {
      orders = {
        source_endpoint     = "source"
        target_endpoint     = "target"
        table_mappings_json = "{\"rules\":[]}"
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.dms_vpc) == 0 && length(aws_iam_role.dms_cloudwatch_logs) == 0 && length(aws_iam_role.dms_access_for_endpoint) == 0
    error_message = "The account-level roles must only be created when asked for."
  }
}

run "creates_the_service_roles_when_asked" {
  command = plan

  variables {
    create_service_roles = true
  }

  assert {
    condition     = aws_iam_role.dms_vpc[0].name == "dms-vpc-role" && aws_iam_role.dms_cloudwatch_logs[0].name == "dms-cloudwatch-logs-role"
    error_message = "DMS finds its service roles by these exact names."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.dms_vpc[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
    error_message = "dms-vpc-role needs the VPC management policy, in the current partition."
  }

  assert {
    condition     = length(aws_iam_role.dms_access_for_endpoint) == 0
    error_message = "create_service_roles must not create dms-access-for-endpoint, which the console often creates already."
  }
}

run "creates_the_endpoint_access_role_when_asked" {
  command = plan

  variables {
    create_endpoint_access_role = true
  }

  assert {
    condition     = length(aws_iam_role.dms_vpc) == 0 && length(aws_iam_role.dms_cloudwatch_logs) == 0
    error_message = "create_endpoint_access_role must create only dms-access-for-endpoint."
  }

  assert {
    condition     = aws_iam_role.dms_access_for_endpoint[0].name == "dms-access-for-endpoint"
    error_message = "A Redshift target needs dms-access-for-endpoint, by that exact name."
  }

  assert {
    condition     = toset(one(one(data.aws_iam_policy_document.dms_access_for_endpoint_assume_role[0].statement).principals).identifiers) == toset(["dms.amazonaws.com", "redshift.amazonaws.com"])
    error_message = "Both DMS and Redshift must be able to assume dms-access-for-endpoint."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.dms_access_for_endpoint[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"
    error_message = "dms-access-for-endpoint needs the Redshift S3 policy, in the current partition."
  }
}

run "refuses_a_task_naming_an_unknown_endpoint" {
  command = plan

  variables {
    tasks = {
      orders = {
        source_endpoint     = "typo"
        target_endpoint     = "target"
        table_mappings_json = "{\"rules\":[]}"
      }
    }
  }

  expect_failures = [aws_dms_replication_task.this]
}
