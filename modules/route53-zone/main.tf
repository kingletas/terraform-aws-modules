locals {
  is_private = length(var.private_vpc_ids) > 0
  tags       = merge(var.tags, { Name = var.name })
}

resource "aws_route53_zone" "this" {
  name          = var.name
  comment       = var.comment
  force_destroy = var.force_destroy

  dynamic "vpc" {
    for_each = var.private_vpc_ids

    content {
      vpc_id = vpc.value
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !var.enable_query_logging || var.query_log_group_arn != null
      error_message = "Query logging needs query_log_group_arn."
    }

    precondition {
      condition     = !var.enable_query_logging || !local.is_private
      error_message = "Query logging is only available on a public zone."
    }
  }
}

resource "aws_route53_health_check" "this" {
  for_each = var.health_checks

  fqdn              = each.value.fqdn
  ip_address        = each.value.ip_address
  port              = each.value.port
  type              = each.value.type
  resource_path     = each.value.resource_path
  failure_threshold = each.value.failure_threshold
  request_interval  = each.value.request_interval
  regions           = each.value.regions

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type

  ttl     = each.value.alias_name == null ? each.value.ttl : null
  records = each.value.alias_name == null ? each.value.records : null

  set_identifier  = each.value.set_identifier
  health_check_id = each.value.health_check_id

  dynamic "alias" {
    for_each = each.value.alias_name == null ? [] : [each.value]

    content {
      name                   = alias.value.alias_name
      zone_id                = alias.value.alias_zone_id
      evaluate_target_health = alias.value.alias_evaluate_target_health
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = each.value.weight == null ? [] : [each.value.weight]

    content {
      weight = weighted_routing_policy.value
    }
  }

  dynamic "failover_routing_policy" {
    for_each = each.value.failover == null ? [] : [each.value.failover]

    content {
      type = failover_routing_policy.value
    }
  }
}

resource "aws_route53_query_log" "this" {
  count = var.enable_query_logging ? 1 : 0

  zone_id                  = aws_route53_zone.this.zone_id
  cloudwatch_log_group_arn = var.query_log_group_arn
}
