# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name           = "plan-test"
  selection_tags = { marked = { key = "Backup", value = "true" } }
}

run "plans_rules_with_cold_storage" {
  command = plan

  variables {
    rules = {
      daily  = { schedule = "cron(0 5 * * ? *)" }
      weekly = { schedule = "cron(0 5 ? * SUN *)", cold_storage_after_days = 30, delete_after_days = 120 }
    }
  }

  assert {
    condition     = aws_backup_selection.this[0].name == "plan-test-selection"
    error_message = "The selection is named after the plan."
  }
}

run "refuses_cold_storage_kept_under_90_days" {
  command = plan

  variables {
    rules = {
      weekly = { schedule = "cron(0 5 ? * SUN *)", cold_storage_after_days = 30, delete_after_days = 119 }
    }
  }

  expect_failures = [var.rules]
}

run "refuses_a_name_too_long_for_the_selection" {
  command = plan

  variables {
    name  = "plan-test-a-name-that-is-longer-than-forty-chars"
    rules = { daily = { schedule = "cron(0 5 * * ? *)" } }
  }

  expect_failures = [var.name]
}

run "leaves_s3_policies_off_by_default" {
  command = plan

  variables {
    rules = { daily = { schedule = "cron(0 5 * * ? *)" } }
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.s3_backup) == 0 && length(aws_iam_role_policy_attachment.s3_restore) == 0
    error_message = "The S3 policies must only be attached when asked for."
  }
}

run "lets_the_role_back_up_s3_when_asked" {
  command = plan

  variables {
    rules             = { daily = { schedule = "cron(0 5 * * ? *)" } }
    s3_backup_enabled = true
  }

  assert {
    condition     = aws_iam_role_policy_attachment.s3_backup[0].policy_arn == "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
    error_message = "Backing up S3 needs the S3 backup policy, in the current partition."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.s3_restore[0].policy_arn == "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
    error_message = "Restoring S3, and generating data keys for an SSE-KMS bucket, needs the S3 restore policy."
  }
}
