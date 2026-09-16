data "aws_caller_identity" "current" {}

locals {
  prefix = format("%s-%s", var.name, var.environment)

  tags = {
    Environment = var.environment
    Purpose     = "partner-file-exchange"
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Partner file exchange at rest"

  service_principals = [format("logs.%s.amazonaws.com", var.region)]

  # CloudWatch alarms and AWS Backup job events publish to the encrypted alert topic.
  delivery_service_principals = ["cloudwatch.amazonaws.com", "backup.amazonaws.com"]

  tags = local.tags
}

module "exchange" {
  source = "../../modules/s3-bucket"

  name        = format("%s-%s", local.prefix, data.aws_caller_identity.current.account_id)
  kms_key_arn = module.kms.arn

  # A partner overwriting yesterday's file with today's should not lose
  # yesterday's, and a partner deleting one by accident should be recoverable.
  versioning_enabled = true

  lifecycle_rules = merge(
    {
      expire = {
        expiration_days                    = var.retention_days
        noncurrent_version_expiration_days = 90
      }
    },
    var.archive_after_days > 0 ? {
      archive = {
        transition_days          = var.archive_after_days
        transition_storage_class = "STANDARD_IA"
      }
    } : {}
  )

  tags = local.tags
}

module "sftp" {
  source = "../../modules/transfer-server"

  name        = local.prefix
  bucket_name = module.exchange.id
  kms_key_arn = module.kms.arn

  bucket_kms_key = { arn = module.kms.arn }

  protocols     = ["SFTP"]
  endpoint_type = "PUBLIC"

  # The 2025 policy drops the older key exchanges. A partner on an ancient
  # client will fail to connect, which is the trade being made deliberately.
  security_policy_name = "TransferSecurityPolicy-2025-03"

  users = {
    for username, partner in var.partners : username => {
      public_keys = partner.public_keys
      read_only   = partner.read_only
    }
  }

  log_retention_days = 2557

  tags = local.tags
}

# Everything a partner sends is backed up independently of S3 versioning,
# because a lifecycle rule and a bad prefix can both remove a version.
module "backups" {
  source = "../../modules/backup-plan"

  name              = local.prefix
  vault_kms_key_arn = module.kms.arn

  # The exchange bucket is S3 under the customer key, which the key policy lets IAM grant.
  s3_backup_enabled = true

  rules = {
    daily = {
      schedule          = "cron(0 7 * * ? *)"
      delete_after_days = 90
    }
  }

  selection_tags = {
    exchange = {
      key   = "Purpose"
      value = "partner-file-exchange"
    }
  }

  notifications = {
    sns_topic_arn = module.alerts.arn
  }

  tags = local.tags
}

module "alerts" {
  source = "../../modules/sns-topic"

  name       = format("%s-alerts", local.prefix)
  kms_key_id = module.kms.key_id

  # Alarms and backup job events are the only publishers, and only from this account.
  publishing_services = local.alert_publishers

  subscriptions = var.alert_email == null ? {} : {
    oncall = {
      protocol = "email"
      endpoint = var.alert_email
    }
  }

  tags = local.tags
}

locals {
  alert_publishers = ["cloudwatch.amazonaws.com", "backup.amazonaws.com"]
}

locals {
  auth_failure_namespace = format("PartnerExchange/%s", local.prefix)

  # Only failures naming a real partner, so the background of scanners guessing usernames stays silent.
  auth_failure_pattern = format("{ $.activity-type = \"AUTH_FAILURE\" && (%s) }",
    join(" || ", [for username in sort(keys(var.partners)) : format("$.user = \"%s\"", username)])
  )
}

# AWS/Transfer publishes no authentication metric, so the structured transfer log is counted instead.
resource "aws_cloudwatch_log_metric_filter" "auth_failures" {
  name           = format("%s-partner-auth-failures", local.prefix)
  log_group_name = module.sftp.log_group_name
  pattern        = local.auth_failure_pattern

  metric_transformation {
    name          = "PartnerAuthFailures"
    namespace     = local.auth_failure_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }

  lifecycle {
    precondition {
      condition     = length(local.auth_failure_pattern) <= 1024
      error_message = "Too many partners for one metric filter pattern, which CloudWatch Logs caps at 1024 characters."
    }
  }
}

module "alarms" {
  source = "../../modules/cloudwatch-alarm"

  default_alarm_actions = [module.alerts.arn]
  default_ok_actions    = [module.alerts.arn]

  alarms = merge(
    {
      # A partner whose key stopped working, or somebody trying keys against a real partner account.
      "${local.prefix}-partner-auth-failures" = {
        description         = "Repeated SFTP authentication failures against a partner username"
        metric_name         = aws_cloudwatch_log_metric_filter.auth_failures.metric_transformation[0].name
        namespace           = local.auth_failure_namespace
        statistic           = "Sum"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = 5
        evaluation_periods  = 1
        treat_missing_data  = "notBreaching"
      }
    },

    # Only useful where a partner is contracted to send something daily.
    var.notify_on_upload ? {
      "${local.prefix}-no-files" = {
        description         = "No files have arrived in 24 hours"
        metric_name         = "FilesIn"
        namespace           = "AWS/Transfer"
        statistic           = "Sum"
        comparison_operator = "LessThanThreshold"
        threshold           = 1
        evaluation_periods  = 1
        period              = 86400
        treat_missing_data  = "breaching"
        dimensions          = { ServerId = module.sftp.id }
      }
    } : {}
  )

  tags = local.tags
}
