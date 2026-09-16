locals {
  tags = merge(var.tags, { Name = var.name })

  # A replacement gets a new name, so create_before_destroy never collides with the group it replaces.
  target_group_names = {
    for key, group in var.target_groups : key => format(
      "%s-%s",
      replace(substr(replace(format("%s-%s", var.name, key), "/[^a-zA-Z0-9-]/", "-"), 0, 25), "/-+$/", ""),
      substr(sha1(jsonencode([key, var.vpc_id, group.port, group.protocol, group.target_type])), 0, 6)
    )
  }
}

resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "network"
  internal           = var.internal
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_deletion_protection       = var.enable_deletion_protection

  dynamic "access_logs" {
    for_each = var.access_logs == null ? [] : [var.access_logs]

    content {
      bucket  = access_logs.value.bucket
      prefix  = access_logs.value.prefix
      enabled = access_logs.value.enabled
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition = alltrue([
        for name, listener in var.listeners : contains(keys(var.target_groups), listener.target_group)
      ])
      error_message = "Every listener must name one of the target_groups."
    }
  }
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = local.target_group_names[each.key]
  vpc_id      = var.vpc_id
  port        = each.value.port
  protocol    = each.value.protocol
  target_type = each.value.target_type

  deregistration_delay = each.value.deregistration_delay
  preserve_client_ip   = each.value.preserve_client_ip
  proxy_protocol_v2    = each.value.proxy_protocol_v2

  health_check {
    protocol            = each.value.health_check_protocol
    port                = each.value.health_check_port
    path                = contains(["HTTP", "HTTPS"], each.value.health_check_protocol) ? each.value.health_check_path : null
    interval            = each.value.health_check_interval
    healthy_threshold   = each.value.health_check_healthy_threshold
    unhealthy_threshold = each.value.health_check_unhealthy_threshold
  }

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.certificate_arn
  ssl_policy        = each.value.protocol == "TLS" ? each.value.ssl_policy : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group].arn
  }

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}
