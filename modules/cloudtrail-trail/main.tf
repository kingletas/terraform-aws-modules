locals {
  # All selects both, so it adds no readOnly field selector.
  read_only_values = {
    All       = []
    ReadOnly  = ["true"]
    WriteOnly = ["false"]
  }

  # With no data events and management events at All, the trail keeps AWS's default selector.
  select_management_events = var.include_management_events && (
    length(var.data_events) > 0 || var.management_events_read_write_type != "All"
  )
}

resource "aws_cloudtrail" "this" {
  name           = var.name
  s3_bucket_name = var.s3_bucket_name
  s3_key_prefix  = var.s3_key_prefix

  is_multi_region_trail         = var.is_multi_region_trail
  is_organization_trail         = var.is_organization_trail
  include_global_service_events = var.include_global_service_events
  enable_log_file_validation    = var.enable_log_file_validation
  enable_logging                = true

  kms_key_id                 = var.kms_key_arn
  cloud_watch_logs_group_arn = var.cloudwatch_log_group_arn == null ? null : format("%s:*", var.cloudwatch_log_group_arn)
  cloud_watch_logs_role_arn  = var.cloudwatch_role_arn
  sns_topic_name             = var.sns_topic_name

  # Advanced selectors replace the basic management selector, so management events are selected here explicitly.
  dynamic "advanced_event_selector" {
    for_each = local.select_management_events ? [var.management_events_read_write_type] : []

    content {
      name = "management-events"

      field_selector {
        field  = "eventCategory"
        equals = ["Management"]
      }

      dynamic "field_selector" {
        for_each = local.read_only_values[advanced_event_selector.value]

        content {
          field  = "readOnly"
          equals = [field_selector.value]
        }
      }
    }
  }

  dynamic "advanced_event_selector" {
    for_each = var.data_events

    content {
      name = advanced_event_selector.key

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }

      field_selector {
        field  = "resources.type"
        equals = [advanced_event_selector.value.resource_type]
      }

      field_selector {
        field       = "resources.ARN"
        starts_with = advanced_event_selector.value.resource_values
      }

      dynamic "field_selector" {
        for_each = local.read_only_values[advanced_event_selector.value.read_write_type]

        content {
          field  = "readOnly"
          equals = [field_selector.value]
        }
      }
    }
  }

  dynamic "insight_selector" {
    for_each = var.insight_types

    content {
      insight_type = insight_selector.value
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = var.include_management_events || length(var.data_events) > 0
      error_message = "A trail with include_management_events false needs at least one data event, or it records nothing."
    }

    precondition {
      condition     = var.cloudwatch_log_group_arn == null || var.cloudwatch_role_arn != null
      error_message = "Delivering to CloudWatch Logs needs cloudwatch_role_arn."
    }
  }
}
