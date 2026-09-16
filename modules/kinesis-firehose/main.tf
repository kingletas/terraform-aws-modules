locals {
  to_s3   = var.s3_destination != null
  logging = var.log_group_name != null

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.name
  destination = local.to_s3 ? "extended_s3" : "http_endpoint"

  server_side_encryption {
    enabled  = true
    key_type = var.kms_key_arn == null ? "AWS_OWNED_CMK" : "CUSTOMER_MANAGED_CMK"
    key_arn  = var.kms_key_arn
  }

  dynamic "extended_s3_configuration" {
    for_each = var.s3_destination == null ? [] : [var.s3_destination]

    content {
      role_arn            = var.role_arn
      bucket_arn          = extended_s3_configuration.value.bucket_arn
      prefix              = extended_s3_configuration.value.prefix
      error_output_prefix = extended_s3_configuration.value.error_output_prefix
      buffering_size      = extended_s3_configuration.value.buffering_size
      buffering_interval  = extended_s3_configuration.value.buffering_interval
      compression_format  = extended_s3_configuration.value.compression_format
      kms_key_arn         = extended_s3_configuration.value.kms_key_arn

      dynamic "cloudwatch_logging_options" {
        for_each = local.logging ? [1] : []

        content {
          enabled         = true
          log_group_name  = var.log_group_name
          log_stream_name = var.log_stream_name
        }
      }
    }
  }

  dynamic "http_endpoint_configuration" {
    for_each = var.http_endpoint_destination == null ? [] : [var.http_endpoint_destination]

    content {
      url                = http_endpoint_configuration.value.url
      name               = http_endpoint_configuration.value.name
      access_key         = http_endpoint_configuration.value.access_key
      role_arn           = var.role_arn
      buffering_size     = http_endpoint_configuration.value.buffering_size
      buffering_interval = http_endpoint_configuration.value.buffering_interval
      retry_duration     = http_endpoint_configuration.value.retry_duration
      s3_backup_mode     = http_endpoint_configuration.value.backup_mode

      request_configuration {
        content_encoding = http_endpoint_configuration.value.content_encoding

        dynamic "common_attributes" {
          for_each = http_endpoint_configuration.value.common_attributes

          content {
            name  = common_attributes.key
            value = common_attributes.value
          }
        }
      }

      # Mandatory, whatever the backup mode. With FailedDataOnly it holds only
      # what the endpoint refused, which is the copy you go looking for.
      s3_configuration {
        role_arn            = var.role_arn
        bucket_arn          = http_endpoint_configuration.value.backup_bucket_arn
        prefix              = http_endpoint_configuration.value.backup_prefix
        error_output_prefix = http_endpoint_configuration.value.backup_error_prefix
        compression_format  = "GZIP"
        kms_key_arn         = var.kms_key_arn
      }

      dynamic "cloudwatch_logging_options" {
        for_each = local.logging ? [1] : []

        content {
          enabled         = true
          log_group_name  = var.log_group_name
          log_stream_name = var.log_stream_name
        }
      }
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = (var.s3_destination == null) != (var.http_endpoint_destination == null)
      error_message = "Set exactly one of s3_destination and http_endpoint_destination."
    }
  }
}
