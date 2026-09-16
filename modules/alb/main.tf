locals {
  https_enabled = var.create_https_listener
  tags          = merge(var.tags, { Name = var.name })

  # A replacement gets a new name, so create_before_destroy never collides with the group it replaces.
  target_group_names = {
    for key, group in var.target_groups : key => format(
      "%s-%s",
      replace(substr(replace(format("%s-%s", var.name, key), "/[^a-zA-Z0-9-]/", "-"), 0, 25), "/-+$/", ""),
      substr(sha1(jsonencode([key, var.vpc_id, group.port, group.protocol, group.protocol_version, group.target_type])), 0, 6)
    )
  }
}

# Public or internal is the caller's choice through var.internal; a storefront has to be public.
#trivy:ignore:AWS-0053
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = var.internal
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids

  idle_timeout               = var.idle_timeout
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = var.drop_invalid_header_fields
  enable_http2               = var.enable_http2

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
      condition     = var.default_target_group == null ? var.default_fixed_response != null : contains(keys(var.target_groups), var.default_target_group)
      error_message = "The default_target_group must name one of the target_groups, or default_fixed_response must be set."
    }

    precondition {
      condition     = alltrue([for rule in values(var.listener_rules) : contains(keys(var.target_groups), rule.target_group)])
      error_message = "Every listener rule must name one of the target_groups."
    }

    precondition {
      condition     = !var.create_https_listener || var.certificate_arn != null
      error_message = "An HTTPS listener needs a certificate_arn. Set create_https_listener = false for HTTP only."
    }

    precondition {
      condition     = var.create_https_listener || var.create_http_listener
      error_message = "The load balancer needs a listener: keep create_http_listener on while create_https_listener is off."
    }
  }
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name             = local.target_group_names[each.key]
  vpc_id           = var.vpc_id
  port             = each.value.port
  protocol         = each.value.protocol
  protocol_version = each.value.protocol_version
  target_type      = each.value.target_type

  deregistration_delay = each.value.deregistration_delay
  slow_start           = each.value.slow_start

  health_check {
    path                = each.value.health_check_path
    matcher             = each.value.health_check_matcher
    interval            = each.value.health_check_interval
    timeout             = each.value.health_check_timeout
    healthy_threshold   = each.value.health_check_healthy_threshold
    unhealthy_threshold = each.value.health_check_unhealthy_threshold
    protocol            = each.value.protocol
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness_enabled ? [each.value] : []

    content {
      type            = "lb_cookie"
      cookie_duration = stickiness.value.stickiness_duration
      enabled         = true
    }
  }

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  dynamic "default_action" {
    for_each = var.default_fixed_response == null ? [1] : []

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this[var.default_target_group].arn
    }
  }

  dynamic "default_action" {
    for_each = var.default_fixed_response == null ? [] : [var.default_fixed_response]

    content {
      type = "fixed-response"

      fixed_response {
        status_code  = tostring(default_action.value.status_code)
        content_type = default_action.value.content_type
        message_body = default_action.value.message_body
      }
    }
  }

  tags = local.tags
}

resource "aws_lb_listener_certificate" "this" {
  for_each = local.https_enabled ? var.additional_certificate_arns : {}

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value
}

# Port 80 redirects to HTTPS once a certificate is set, unless redirect_http_to_https is turned off.
#trivy:ignore:AWS-0054
resource "aws_lb_listener" "http" {
  count = var.create_http_listener ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https_enabled && var.redirect_http_to_https ? [1] : []

    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = !(local.https_enabled && var.redirect_http_to_https) && var.default_fixed_response == null ? [1] : []

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this[var.default_target_group].arn
    }
  }

  dynamic "default_action" {
    for_each = !(local.https_enabled && var.redirect_http_to_https) && var.default_fixed_response != null ? [var.default_fixed_response] : []

    content {
      type = "fixed-response"

      fixed_response {
        status_code  = tostring(default_action.value.status_code)
        content_type = default_action.value.content_type
        message_body = default_action.value.message_body
      }
    }
  }

  tags = local.tags
}

moved {
  from = aws_lb_listener.http
  to   = aws_lb_listener.http[0]
}

resource "aws_lb_listener_rule" "this" {
  for_each = var.listener_rules

  listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group].arn
  }

  dynamic "condition" {
    for_each = each.value.host_headers == null ? [] : [each.value.host_headers]

    content {
      host_header {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.path_patterns == null ? [] : [each.value.path_patterns]

    content {
      path_pattern {
        values = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = coalesce(each.value.http_headers, {})

    content {
      http_header {
        http_header_name = condition.key
        values           = condition.value
      }
    }
  }

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}
