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
    service_principals = ["logs.us-east-1.amazonaws.com"]
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
