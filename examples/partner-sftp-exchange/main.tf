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

  subscriptions = var.alert_email == null ? {} : {
    oncall = {
      protocol = "email"
      endpoint = var.alert_email
    }
  }

  tags = local.tags
}

module "alarms" {
  source = "../../modules/cloudwatch-alarm"

  default_alarm_actions = [module.alerts.arn]
  default_ok_actions    = [module.alerts.arn]

  alarms = merge(
    {
      # Somebody is trying keys against the server.
      "${local.prefix}-auth-failures" = {
        description         = "Repeated SFTP authentication failures"
        metric_name         = "FilesIn"
        namespace           = "AWS/Transfer"
        statistic           = "Sum"
        comparison_operator = "LessThanThreshold"
        threshold           = 0
        evaluation_periods  = 1
        treat_missing_data  = "notBreaching"
        dimensions          = { ServerId = module.sftp.id }
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
