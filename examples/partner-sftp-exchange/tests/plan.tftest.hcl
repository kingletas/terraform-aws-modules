# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    partners         = { acme = { public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlanTestOnlyNotARealKeyAtAll plan-test"] } }
    notify_on_upload = true
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.auth_failures.pattern == "{ $.activity-type = \"AUTH_FAILURE\" && ($.user = \"acme\") }"
    error_message = "The auth-failure metric must count AUTH_FAILURE entries naming a configured partner."
  }

  assert {
    condition     = one(aws_cloudwatch_log_metric_filter.auth_failures.metric_transformation).namespace == "PartnerExchange/exchange-production"
    error_message = "The auth-failure metric must be published under this exchange's own namespace."
  }

  assert {
    condition     = toset(local.alert_publishers) == toset(["cloudwatch.amazonaws.com", "backup.amazonaws.com"])
    error_message = "The alert topic must let CloudWatch alarms and AWS Backup publish."
  }

  assert {
    condition     = contains(module.backups.role_policy_arns, "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup") && contains(module.backups.role_policy_arns, "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore")
    error_message = "The backup role must be able to back up the KMS-encrypted exchange bucket."
  }
}

run "plans_with_several_partners" {
  command = plan

  variables {
    partners = {
      acme            = { public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlanTestOnlyNotARealKeyAtAll plan-test"] }
      globex-readonly = { public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlanTestOnlyNotARealKeyAtAll plan-test"], read_only = true }
    }
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.auth_failures.pattern == "{ $.activity-type = \"AUTH_FAILURE\" && ($.user = \"acme\" || $.user = \"globex-readonly\") }"
    error_message = "Every configured partner must be named in the auth-failure filter."
  }
}
