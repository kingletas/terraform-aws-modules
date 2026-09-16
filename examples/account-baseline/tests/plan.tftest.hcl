# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  assert {
    condition     = toset([for statement in data.aws_iam_policy_document.trail_bucket.statement : statement.sid]) == toset(["AllowTrailAclCheck", "AllowTrailWrite"])
    error_message = "The CloudTrail grants must be passed to the bucket module, and must not redefine its TLS-only statement."
  }

  assert {
    condition     = one([for statement in data.aws_iam_policy_document.trail_bucket.statement : statement.resources if statement.sid == "AllowTrailWrite"]) == toset(["arn:aws:s3:::baseline-production-cloudtrail-123456789012/AWSLogs/123456789012/*"])
    error_message = "CloudTrail must be allowed to write only under this account's AWSLogs prefix."
  }

  assert {
    condition     = toset(local.security_topic_publishers) == toset(["cloudwatch.amazonaws.com", "backup.amazonaws.com"])
    error_message = "The security topic must let CloudWatch alarms and AWS Backup job notifications publish."
  }
}
