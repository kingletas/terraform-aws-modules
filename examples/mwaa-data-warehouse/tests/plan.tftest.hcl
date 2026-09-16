# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "random" {}

run "plans_with_real_values" {
  command = plan

  assert {
    condition     = toset(one([for statement in data.aws_iam_policy_document.redshift_audit_logging.statement : statement.actions if statement.sid == "AllowRedshiftAuditLogging"])) == toset(["s3:PutObject", "s3:GetBucketAcl"])
    error_message = "Redshift audit logging needs s3:PutObject and s3:GetBucketAcl on the log bucket."
  }

  assert {
    condition     = toset(flatten([for principal in data.aws_iam_policy_document.redshift_audit_logging.statement[0].principals : principal.identifiers])) == toset(["redshift.amazonaws.com"])
    error_message = "The audit log grant must name the Redshift service principal."
  }

  assert {
    condition = toset(data.aws_iam_policy_document.redshift_audit_logging.statement[0].resources) == toset([
      "arn:aws:s3:::warehouse-production-logs-123456789012",
      "arn:aws:s3:::warehouse-production-logs-123456789012/*",
    ])
    error_message = "The audit log grant must cover the log bucket and its objects, and nothing else."
  }

  assert {
    condition     = toset(one([for condition in data.aws_iam_policy_document.redshift_audit_logging.statement[0].condition : condition.values if condition.variable == "aws:SourceArn"])) == toset(["arn:aws:redshift:us-east-1:123456789012:cluster:warehouse-production"])
    error_message = "Only this warehouse cluster may write audit logs, named by aws:SourceArn."
  }

  assert {
    condition     = toset(one([for condition in data.aws_iam_policy_document.redshift_audit_logging.statement[0].condition : condition.values if condition.variable == "aws:SourceAccount"])) == toset(["123456789012"])
    error_message = "The audit log grant must be limited to this account by aws:SourceAccount."
  }

  assert {
    condition = toset(flatten([for statement in data.aws_iam_policy_document.redshift.statement : statement.resources if statement.sid == "ReadWriteStaging"])) == toset([
      "arn:aws:s3:::warehouse-production-staging-123456789012",
      "arn:aws:s3:::warehouse-production-staging-123456789012/*",
    ])
    error_message = "The Redshift data role must reach the staging bucket only, never the audit log bucket."
  }

  assert {
    condition     = local.staging_bucket != local.audit_logs_bucket
    error_message = "Audit logs must have a bucket of their own, apart from COPY and UNLOAD staging."
  }

  assert {
    condition     = alltrue([for role in ["dms_vpc", "dms_cloudwatch_logs"] : contains(keys(module.replication.service_role_arns), role)])
    error_message = "The example creates the account-level DMS service roles by default."
  }

  assert {
    condition     = contains(keys(module.replication.service_role_arns), "dms_access_for_endpoint")
    error_message = "The Redshift target needs dms-access-for-endpoint, which the example creates by default."
  }
}

run "plans_on_the_smallest_airflow_class" {
  command = plan

  variables {
    airflow_environment_class       = "mw1.micro"
    create_dms_service_roles        = false
    create_dms_endpoint_access_role = false
  }

  assert {
    condition     = local.airflow_micro
    error_message = "mw1.micro must select the single-scheduler, single-worker shape."
  }

  assert {
    condition     = length(module.replication.service_role_arns) == 0
    error_message = "Turning both DMS role variables off must leave the account-level DMS roles alone."
  }
}
