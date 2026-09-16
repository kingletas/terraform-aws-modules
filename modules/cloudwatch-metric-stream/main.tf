locals {
  tags = merge(var.tags, { Name = var.name })
}

resource "aws_cloudwatch_metric_stream" "this" {
  name          = var.name
  role_arn      = var.role_arn
  firehose_arn  = var.firehose_arn
  output_format = var.output_format

  include_linked_accounts_metrics = var.include_linked_accounts_metrics

  dynamic "include_filter" {
    for_each = var.include_namespaces

    content {
      namespace    = include_filter.key
      metric_names = include_filter.value
    }
  }

  dynamic "exclude_filter" {
    for_each = var.exclude_namespaces

    content {
      namespace    = exclude_filter.key
      metric_names = exclude_filter.value
    }
  }

  dynamic "statistics_configuration" {
    for_each = var.statistics_configurations

    content {
      additional_statistics = statistics_configuration.value.additional_statistics

      dynamic "include_metric" {
        for_each = statistics_configuration.value.metrics

        content {
          namespace   = include_metric.value.namespace
          metric_name = include_metric.value.metric_name
        }
      }
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = length(var.include_namespaces) == 0 || length(var.exclude_namespaces) == 0
      error_message = "Set include_namespaces or exclude_namespaces, not both. AWS accepts one list or the other."
    }
  }
}
