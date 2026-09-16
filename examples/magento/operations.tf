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

module "alarms" {
  source = "../../modules/cloudwatch-alarm"

  default_alarm_actions = [module.alerts.arn]
  default_ok_actions    = [module.alerts.arn]

  alarms = merge(
    {
      # A rate, not a count. Fifty errors during a campaign is a different
      # thing from fifty errors at 3am.
      "${local.prefix}-5xx-rate" = {
        description         = "More than 2% of storefront responses are 5xx"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 2
        evaluation_periods  = 3
        datapoints_to_alarm = 2
        treat_missing_data  = "notBreaching"

        metric_query = [
          { id = "errors", metric_name = "HTTPCode_Target_5XX_Count", namespace = "AWS/ApplicationELB", stat = "Sum", dimensions = { LoadBalancer = module.alb.arn_suffix } },
          { id = "requests", metric_name = "RequestCount", namespace = "AWS/ApplicationELB", stat = "Sum", dimensions = { LoadBalancer = module.alb.arn_suffix } },
          { id = "rate", expression = "IF(requests > 100, errors / requests * 100, 0)", label = "5xx rate", return_data = true },
        ]
      }

      "${local.prefix}-healthy-hosts" = {
        description         = "The web tier is below its minimum healthy count"
        metric_name         = "HealthyHostCount"
        namespace           = "AWS/ApplicationELB"
        statistic           = "Minimum"
        comparison_operator = "LessThanThreshold"
        threshold           = local.capacity.min
        evaluation_periods  = 2
        treat_missing_data  = "breaching"
        dimensions = {
          LoadBalancer = module.alb.arn_suffix
          TargetGroup  = module.alb.target_group_arn_suffixes["web"]
        }
      }

      "${local.prefix}-latency" = {
        description         = "p99 storefront latency above two seconds"
        metric_name         = "TargetResponseTime"
        namespace           = "AWS/ApplicationELB"
        extended_statistic  = "p99"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 2
        evaluation_periods  = 3
        datapoints_to_alarm = 2
        treat_missing_data  = "notBreaching"
        dimensions          = { LoadBalancer = module.alb.arn_suffix }
      }

      "${local.prefix}-database-cpu" = {
        description         = "Aurora above 80% CPU"
        metric_name         = "CPUUtilization"
        namespace           = "AWS/RDS"
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80
        evaluation_periods  = 3
        dimensions          = { DBClusterIdentifier = module.database.cluster_identifier }
      }

      # An evicted key here is a shopper logged out mid-checkout, so the right
      # threshold is zero.
      "${local.prefix}-cache-evictions" = {
        description         = "The session and cache cluster is evicting keys"
        metric_name         = "Evictions"
        namespace           = "AWS/ElastiCache"
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        evaluation_periods  = 2
        treat_missing_data  = "notBreaching"
        dimensions          = { ReplicationGroupId = module.cache.id }
      }

      "${local.prefix}-search-red" = {
        description         = "OpenSearch is red, so a catalogue index is unavailable"
        metric_name         = "ClusterStatus.red"
        namespace           = "AWS/ES"
        statistic           = "Maximum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        evaluation_periods  = 1
        treat_missing_data  = "notBreaching"
        dimensions = {
          DomainName = module.search.domain_name
          ClientId   = data.aws_caller_identity.current.account_id
        }
      }
    },

    # A singleton that stops is not replaced by anything. The cron node is the
    # sharpest case: nothing fails, work simply stops being done.
    {
      for role in module.singletons.roles : "${local.prefix}-${role}-down" => {
        description         = "The ${role} node has failed its status check"
        metric_name         = "StatusCheckFailed"
        namespace           = "AWS/EC2"
        statistic           = "Maximum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        evaluation_periods  = 2
        treat_missing_data  = "breaching"
        dimensions          = { InstanceId = module.singletons.instance_ids_by_role[role][0] }
      }
    }
  )

  tags = local.tags
}

module "dashboard" {
  source = "../../modules/cloudwatch-dashboard"

  name = format("%s-storefront", local.prefix)

  widgets = [
    {
      type     = "text"
      width    = 24
      height   = 2
      markdown = "# ${var.domain_name}\n${title(var.environment)} storefront: traffic, latency, capacity and the datastores behind it."
    },
    {
      title = "Requests and 5xx"
      metrics_json = jsonencode([
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.arn_suffix, { stat = "Sum" }],
        [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }],
      ])
      stat = "Sum"
    },
    {
      title = "Latency, p50 against p99"
      metrics_json = jsonencode([
        ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.arn_suffix, { stat = "p50" }],
        ["...", { stat = "p99" }],
      ])
      annotations_horizontal = [{ value = 2, label = "p99 budget", color = "#d62728" }]
    },
    {
      title        = "Web tier capacity"
      metrics_json = jsonencode([["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", module.web.name]])
      stat         = "Average"
    },
    {
      title = "Aurora"
      metrics_json = jsonencode([
        ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", module.database.cluster_identifier],
        [".", "DatabaseConnections", ".", "."],
      ])
    },
    {
      title = "Cache hit rate and evictions"
      metrics_json = jsonencode([
        ["AWS/ElastiCache", "CacheHitRate", "ReplicationGroupId", module.cache.id],
        [".", "Evictions", ".", ".", { stat = "Sum" }],
      ])
    },
  ]
}

module "backups" {
  source = "../../modules/backup-plan"

  name              = local.prefix
  vault_kms_key_arn = module.kms.arn

  rules = {
    daily = {
      schedule          = "cron(0 6 * * ? *)"
      delete_after_days = local.defaults.backup_retention_days
    }
  }

  # The context module puts Backup = true on production resources and nothing
  # else, so this selection needs no environment logic.
  selection_tags = {
    marked = { key = "Backup", value = "true" }
  }

  notifications = {
    sns_topic_arn = module.alerts.arn
  }

  tags = local.tags
}
