locals {
  log_exec = var.execute_command_logging == "OVERRIDE"
  tags     = merge(var.tags, { Name = var.name })
}

resource "aws_cloudwatch_log_group" "exec" {
  count = local.log_exec ? 1 : 0

  name              = format("/aws/ecs/%s/exec", var.name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = var.execute_command_logging

      dynamic "log_configuration" {
        for_each = local.log_exec ? [1] : []

        content {
          cloud_watch_encryption_enabled = var.kms_key_arn != null
          cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec[0].name
        }
      }
    }
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = var.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy

    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}
