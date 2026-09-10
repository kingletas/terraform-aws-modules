module "certificate" {
  source = "../../modules/acm-certificate"

  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.this.zone_id

  tags = local.tags
}

locals {
  # A path rule only exists for a service that asked for one. The default
  # service catches everything else, so it needs no rule at all.
  routed_services = {
    for name, service in var.services : name => service
    if service.path_patterns != null && name != var.default_service
  }
}

module "alb" {
  source = "../../modules/alb"

  name       = substr(local.prefix, 0, 32)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = values(module.vpc.public_subnet_ids)

  security_group_ids = [module.alb_sg.id]
  certificate_arn    = module.certificate.validated_arn

  target_groups = {
    for name, service in var.services : name => {
      port = service.container_port
      # Fargate tasks register by address, not by instance.
      target_type       = "ip"
      health_check_path = service.health_path

      # Fargate replaces a task rather than restarting it, so draining need
      # not be long — but it must outlast the slowest in-flight request.
      deregistration_delay = 30
    }
  }

  default_target_group = var.default_service

  listener_rules = {
    for name, service in local.routed_services : name => {
      priority      = service.priority
      target_group  = name
      path_patterns = service.path_patterns
    }
  }

  tags = local.tags
}

module "waf" {
  source = "../../modules/waf-web-acl"

  name  = local.prefix
  scope = "REGIONAL"

  managed_rule_groups = {
    AWSManagedRulesCommonRuleSet          = { priority = 10, count_only = true }
    AWSManagedRulesKnownBadInputsRuleSet  = { priority = 20 }
    AWSManagedRulesAmazonIpReputationList = { priority = 30 }
  }

  rate_limits = {
    all = {
      priority = 50
      limit    = 5000
    }
  }

  associations = { alb = module.alb.arn }

  tags = local.tags
}

resource "aws_route53_record" "service" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

# --- operations ---

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
      "${local.prefix}-5xx-rate" = {
        description         = "More than 2% of responses are 5xx"
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
    },

    # A service pinned at its ceiling is not coping, and the next traffic
    # increase has nowhere to go.
    {
      for name, service in var.services : "${local.prefix}-${name}-at-ceiling" => {
        description         = "The ${name} service is running at its maximum task count"
        metric_name         = "RunningTaskCount"
        namespace           = "ECS/ContainerInsights"
        statistic           = "Average"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = service.max_capacity
        evaluation_periods  = 3
        treat_missing_data  = "notBreaching"

        dimensions = {
          ClusterName = module.cluster.name
          ServiceName = module.services[name].name
        }
      }
    }
  )

  tags = local.tags
}
