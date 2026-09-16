# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

override_data {
  target = data.aws_iam_session_context.caller
  values = {
    issuer_arn = "arn:aws:iam::123456789012:role/plan-test-deployer"
  }
}

variables {
  name        = "plan-test"
  description = "Plan test key"
}

run "adds_the_caller_to_named_admins" {
  command = plan

  variables {
    admin_arns = ["arn:aws:iam::123456789012:role/plan-test-admin"]
  }

  assert {
    condition = one([
      for statement in data.aws_iam_policy_document.this.statement : one(statement.principals).identifiers
      if statement.sid == "AllowAccountAdministration"
      ]) == toset([
      "arn:aws:iam::123456789012:role/plan-test-admin",
      "arn:aws:iam::123456789012:role/plan-test-deployer",
    ])
    error_message = "The identity running Terraform should administer the key alongside the named admins."
  }
}

run "leaves_the_caller_out_when_asked" {
  command = plan

  variables {
    admin_arns              = ["arn:aws:iam::123456789012:role/plan-test-admin"]
    include_caller_as_admin = false
  }

  assert {
    condition     = length(data.aws_iam_session_context.caller) == 0
    error_message = "The caller should not be looked up when it is not added."
  }

  assert {
    condition = one([
      for statement in data.aws_iam_policy_document.this.statement : one(statement.principals).identifiers
      if statement.sid == "AllowAccountAdministration"
    ]) == toset(["arn:aws:iam::123456789012:role/plan-test-admin"])
    error_message = "Only the named admins should administer the key."
  }
}

run "falls_back_to_account_root_without_admins" {
  command = plan

  assert {
    condition     = length(data.aws_iam_session_context.caller) == 0
    error_message = "Account root already covers the caller."
  }
}

run "grants_delivery_services_scoped_to_the_account" {
  command = plan

  variables {
    delivery_service_principals = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
  }

  assert {
    condition = one([
      for statement in data.aws_iam_policy_document.this.statement : statement.actions
      if statement.sid == "AllowDeliveryServices"
    ]) == toset(["kms:Decrypt", "kms:GenerateDataKey*"])
    error_message = "Delivery services should be able to decrypt and generate data keys, and nothing more."
  }

  assert {
    condition = one(flatten([
      for statement in data.aws_iam_policy_document.this.statement : [for condition in statement.condition : condition.values]
      if statement.sid == "AllowDeliveryServices"
    ])) == "123456789012"
    error_message = "Delivery service use should be scoped to this account."
  }
}

run "refuses_a_delivery_principal_that_is_not_a_service" {
  command = plan

  variables {
    delivery_service_principals = ["arn:aws:iam::123456789012:root"]
  }

  expect_failures = [var.delivery_service_principals]
}

run "grants_services_scoped_to_the_account" {
  command = plan

  variables {
    service_principals = ["sns.amazonaws.com"]
  }

  assert {
    condition = one([
      for statement in data.aws_iam_policy_document.this.statement : one(statement.condition)
      if statement.sid == "AllowServiceUse"
    ]).test == "StringEqualsIfExists"
    error_message = "Service use should be conditioned on the source account where the service sends one."
  }

  assert {
    condition = one(flatten([
      for statement in data.aws_iam_policy_document.this.statement : [for condition in statement.condition : condition.values]
      if statement.sid == "AllowServiceUse"
    ])) == "123456789012"
    error_message = "Service use should be scoped to this account."
  }
}

run "refuses_a_service_principal_that_is_not_a_service" {
  command = plan

  variables {
    service_principals = ["arn:aws:iam::123456789012:root"]
  }

  expect_failures = [var.service_principals]
}

run "scopes_cloudwatch_logs_to_this_accounts_log_groups" {
  command = plan

  variables {
    service_principals = ["logs.us-east-1.amazonaws.com", "logs.eu-west-1.amazonaws.com", "sns.amazonaws.com"]
  }

  assert {
    condition = one([
      for statement in data.aws_iam_policy_document.this.statement : one(statement.principals).identifiers
      if statement.sid == "AllowServiceUse"
    ]) == toset(["sns.amazonaws.com"])
    error_message = "CloudWatch Logs must not share the grant conditioned only on the source account."
  }

  assert {
    condition = jsonencode(one([
      for statement in data.aws_iam_policy_document.this.statement : [
        for condition in statement.condition : [condition.test, condition.variable, sort(condition.values)]
      ]
      if statement.sid == "AllowCloudWatchLogsUse"
      ])) == jsonencode([
      ["ArnLike", "kms:EncryptionContext:aws:logs:arn", ["arn:aws:logs:eu-west-1:123456789012:*", "arn:aws:logs:us-east-1:123456789012:*"]],
    ])
    error_message = "CloudWatch Logs use must require a log group in this account, in the principal's region, and nothing weaker."
  }
}

run "scopes_cloudwatch_logs_named_as_a_delivery_service" {
  command = plan

  variables {
    delivery_service_principals = ["logs.cn-north-1.amazonaws.com.cn"]
  }

  override_data {
    target = data.aws_partition.current
    values = {
      partition  = "aws-cn"
      dns_suffix = "amazonaws.com.cn"
    }
  }

  assert {
    condition = length([
      for statement in data.aws_iam_policy_document.this.statement : statement
      if statement.sid == "AllowDeliveryServices"
    ]) == 0
    error_message = "With only CloudWatch Logs named, there must be no source-account delivery grant."
  }

  assert {
    condition = one(flatten([
      for statement in data.aws_iam_policy_document.this.statement : [
        for condition in statement.condition : condition.values if condition.variable == "kms:EncryptionContext:aws:logs:arn"
      ]
      if statement.sid == "AllowCloudWatchLogsDelivery"
    ])) == "arn:aws-cn:logs:cn-north-1:123456789012:*"
    error_message = "CloudWatch Logs delivery must be scoped to this account's log groups, in the partition's ARN form."
  }
}
