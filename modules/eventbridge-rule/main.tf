resource "aws_cloudwatch_event_rule" "this" {
  name           = var.name
  description    = var.description
  event_bus_name = var.event_bus_name

  schedule_expression = var.schedule_expression
  event_pattern       = var.event_pattern_json
  state               = var.enabled ? "ENABLED" : "DISABLED"

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = (var.schedule_expression != null) != (var.event_pattern_json != null)
      error_message = "Set exactly one of schedule_expression or event_pattern_json."
    }
  }
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = var.targets

  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = var.event_bus_name
  target_id      = each.key
  arn            = each.value.arn
  role_arn       = each.value.role_arn

  input      = each.value.input
  input_path = each.value.input_path

  dynamic "input_transformer" {
    for_each = each.value.input_transformer == null ? [] : [each.value.input_transformer]

    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  dynamic "dead_letter_config" {
    for_each = each.value.dead_letter_arn == null ? [] : [each.value.dead_letter_arn]

    content {
      arn = dead_letter_config.value
    }
  }

  retry_policy {
    maximum_retry_attempts       = each.value.maximum_retry_attempts
    maximum_event_age_in_seconds = each.value.maximum_event_age
  }

  dynamic "sqs_target" {
    for_each = each.value.sqs_message_group_id == null ? [] : [each.value.sqs_message_group_id]

    content {
      message_group_id = sqs_target.value
    }
  }

  dynamic "ecs_target" {
    for_each = each.value.ecs_task_definition_arn == null ? [] : [each.value]

    content {
      task_definition_arn = ecs_target.value.ecs_task_definition_arn
      task_count          = ecs_target.value.ecs_task_count
      launch_type         = ecs_target.value.ecs_launch_type

      network_configuration {
        subnets          = ecs_target.value.ecs_subnet_ids
        security_groups  = ecs_target.value.ecs_security_group_ids
        assign_public_ip = ecs_target.value.ecs_assign_public_ip
      }
    }
  }
}
