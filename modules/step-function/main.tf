locals {
  logging_enabled = var.log_level != "OFF"
  tags            = merge(var.tags, { Name = var.name })
}

resource "aws_cloudwatch_log_group" "this" {
  count = local.logging_enabled ? 1 : 0

  name              = format("/aws/states/%s", var.name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
}

resource "aws_sfn_state_machine" "this" {
  name       = var.name
  type       = var.type
  role_arn   = var.role_arn
  definition = var.definition_json

  dynamic "logging_configuration" {
    for_each = local.logging_enabled ? [1] : []

    content {
      level                  = var.log_level
      include_execution_data = var.include_execution_data
      log_destination        = format("%s:*", aws_cloudwatch_log_group.this[0].arn)
    }
  }

  tracing_configuration {
    enabled = var.tracing_enabled
  }

  tags = local.tags
}
