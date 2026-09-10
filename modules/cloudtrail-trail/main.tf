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
      condition     = var.cloudwatch_log_group_arn == null || var.cloudwatch_role_arn != null
      error_message = "Delivering to CloudWatch Logs needs cloudwatch_role_arn."
    }
  }
}
