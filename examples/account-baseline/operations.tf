module "security_alerts" {
  source = "../../modules/sns-topic"

  name       = format("%s-security", local.prefix)
  kms_key_id = module.kms.key_id

  subscriptions = var.alert_email == null ? {} : {
    security = {
      protocol = "email"
      endpoint = var.alert_email
    }
  }

  tags = local.tags
}

module "security_alarms" {
  source = "../../modules/cloudwatch-alarm"

  default_alarm_actions = [module.security_alerts.arn]

  # No ok_actions. "Root account use has stopped" is not information anyone
  # needs; the alarm is a notification of an event, not a state to recover from.
  default_ok_actions = []

  alarms = {
    "${local.prefix}-root-account-used" = {
      description         = "The root account was used"
      metric_name         = "RootAccountUsage"
      namespace           = "Security"
      statistic           = "Sum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      evaluation_periods  = 1
      period              = 300
      treat_missing_data  = "notBreaching"
    }

    "${local.prefix}-console-without-mfa" = {
      description         = "An IAM user signed in to the console without multi-factor authentication"
      metric_name         = "ConsoleSignInWithoutMfa"
      namespace           = "Security"
      statistic           = "Sum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      evaluation_periods  = 1
      period              = 300
      treat_missing_data  = "notBreaching"
    }

    "${local.prefix}-trail-changed" = {
      description         = "The audit trail was stopped, deleted or reconfigured"
      metric_name         = "TrailConfigurationChanged"
      namespace           = "Security"
      statistic           = "Sum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      evaluation_periods  = 1
      period              = 300
      treat_missing_data  = "notBreaching"
    }

    # Not at one. A handful of denials a day is ordinary; a sudden run of them
    # is somebody enumerating what a set of credentials can reach.
    "${local.prefix}-authorization-failures" = {
      description         = "An unusual number of authorization failures"
      metric_name         = "AuthorizationFailures"
      namespace           = "Security"
      statistic           = "Sum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 20
      evaluation_periods  = 1
      period              = 300
      treat_missing_data  = "notBreaching"
    }
  }

  tags = local.tags
}

module "security_dashboard" {
  source = "../../modules/cloudwatch-dashboard"

  name = format("%s-security", local.prefix)

  widgets = [
    {
      type     = "text"
      width    = 24
      height   = 2
      markdown = "# Account ${local.account_id}\nRoot use, sign-ins without MFA, authorization failures and trail changes. Every panel here should normally read zero."
    },
    {
      title        = "Root account use"
      metrics_json = jsonencode([["Security", "RootAccountUsage"]])
      stat         = "Sum"
      width        = 12
    },
    {
      title        = "Console sign-in without MFA"
      metrics_json = jsonencode([["Security", "ConsoleSignInWithoutMfa"]])
      stat         = "Sum"
      width        = 12
    },
    {
      title        = "Authorization failures"
      metrics_json = jsonencode([["Security", "AuthorizationFailures"]])
      stat         = "Sum"
      width        = 12

      annotations_horizontal = [{ value = 20, label = "alarm", color = "#d62728" }]
    },
    {
      title        = "Trail configuration changes"
      metrics_json = jsonencode([["Security", "TrailConfigurationChanged"]])
      stat         = "Sum"
      width        = 12
    },
  ]
}

# --- backups ---

module "backups" {
  source = "../../modules/backup-plan"

  name              = local.prefix
  vault_kms_key_arn = module.kms.arn

  vault_lock = var.enable_vault_lock ? {
    changeable_for_days = 3
    min_retention_days  = 7
    max_retention_days  = 2555
  } : null

  rules = {
    daily = {
      schedule          = "cron(0 5 * * ? *)"
      delete_after_days = 35
    }

    weekly = {
      schedule                = "cron(0 5 ? * SUN *)"
      cold_storage_after_days = 30
      delete_after_days       = 365
    }

    monthly = {
      schedule                = "cron(0 5 1 * ? *)"
      cold_storage_after_days = 90
      delete_after_days       = 2555
    }
  }

  selection_tags = {
    marked = {
      key   = var.backup_selection_tag.key
      value = var.backup_selection_tag.value
    }
  }

  notifications = {
    sns_topic_arn = module.security_alerts.arn
  }

  tags = local.tags
}
