data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  prefix     = format("%s-%s", var.name, var.environment)
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  tags = {
    Environment = var.environment
    Purpose     = "account-baseline"
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Audit trail and backups at rest"

  service_principals = [
    "cloudtrail.amazonaws.com",
    format("logs.%s.amazonaws.com", var.region),
    "backup.amazonaws.com",
  ]

  # Long, because a key deletion here makes seven years of trail unreadable.
  deletion_window_in_days = 30

  tags = local.tags
}

# --- where the trail is written ---

module "trail_bucket" {
  source = "../../modules/s3-bucket"

  name        = format("%s-cloudtrail-%s", local.prefix, local.account_id)
  kms_key_arn = module.kms.arn

  lifecycle_rules = {
    retain = {
      transition_days          = 90
      transition_storage_class = "GLACIER"
      expiration_days          = var.trail_retention_years * 365
    }
  }

  tags = local.tags
}

# The s3-bucket module writes a TLS-only policy. CloudTrail also needs explicit
# permission to write, and the module deliberately does not edit another
# module's policy, so the whole policy is composed and replaced here.
data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [module.trail_bucket.arn, format("%s/*", module.trail_bucket.arn)]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [module.trail_bucket.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [format("arn:%s:cloudtrail:%s:%s:trail/%s", local.partition, var.region, local.account_id, local.prefix)]
    }
  }

  statement {
    sid       = "AllowTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = [format("%s/AWSLogs/%s/*", module.trail_bucket.arn, local.account_id)]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = module.trail_bucket.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

# --- the queryable copy ---

module "trail_logs" {
  source = "../../modules/cloudwatch-log-group"

  name           = format("/aws/cloudtrail/%s", local.prefix)
  retention_days = var.log_group_retention_days
  kms_key_arn    = module.kms.arn

  # A log line becomes a metric, and a metric is what an alarm can watch.
  # These four are the ones worth waking up for.
  metric_filters = {
    root_account_use = {
      pattern          = "{ $.userIdentity.type = \"Root\" && $.eventType != \"AwsServiceEvent\" }"
      metric_name      = "RootAccountUsage"
      metric_namespace = "Security"
      default_value    = 0
    }

    console_without_mfa = {
      pattern          = "{ $.eventName = \"ConsoleLogin\" && $.additionalEventData.MFAUsed != \"Yes\" && $.userIdentity.type = \"IAMUser\" }"
      metric_name      = "ConsoleSignInWithoutMfa"
      metric_namespace = "Security"
      default_value    = 0
    }

    authorization_failures = {
      pattern          = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
      metric_name      = "AuthorizationFailures"
      metric_namespace = "Security"
      default_value    = 0
    }

    # Somebody turning off the thing that watches them.
    trail_configuration_changed = {
      pattern          = "{ ($.eventName = \"StopLogging\") || ($.eventName = \"DeleteTrail\") || ($.eventName = \"UpdateTrail\") }"
      metric_name      = "TrailConfigurationChanged"
      metric_namespace = "Security"
      default_value    = 0
    }
  }

  tags = local.tags
}

module "trail_role" {
  source = "../../modules/iam-role"

  name             = format("%s-trail", local.prefix)
  description      = "CloudTrail writing to CloudWatch Logs"
  trusted_services = ["cloudtrail.amazonaws.com"]

  inline_policies = {
    write_logs = data.aws_iam_policy_document.trail_role.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "trail_role" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [format("%s:*", module.trail_logs.arn)]
  }
}

module "trail" {
  source = "../../modules/cloudtrail-trail"

  name           = local.prefix
  s3_bucket_name = module.trail_bucket.id
  kms_key_arn    = module.kms.arn

  is_multi_region_trail = true
  is_organization_trail = var.is_organization_trail

  cloudwatch_log_group_arn = module.trail_logs.arn
  cloudwatch_role_arn      = module.trail_role.arn

  insight_types = ["ApiCallRateInsight", "ApiErrorRateInsight"]

  tags = local.tags

  depends_on = [aws_s3_bucket_policy.trail]
}
