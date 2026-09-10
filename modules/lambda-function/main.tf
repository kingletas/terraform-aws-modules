locals {
  is_zip = var.package_type == "Zip"
  tags   = merge(var.tags, { Name = var.name })
}

# Created here rather than left to Lambda, whose implicit group never expires.
resource "aws_cloudwatch_log_group" "this" {
  name              = format("/aws/lambda/%s", var.name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  description   = var.description
  role          = var.role_arn

  package_type  = var.package_type
  architectures = [var.architecture]

  filename          = var.filename
  source_code_hash  = var.source_code_hash
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  image_uri         = var.image_uri

  handler = local.is_zip ? var.handler : null
  runtime = local.is_zip ? var.runtime : null

  memory_size = var.memory_size
  timeout     = var.timeout
  layers      = var.layers
  publish     = var.publish || var.provisioned_concurrency > 0

  reserved_concurrent_executions = var.reserved_concurrent_executions
  kms_key_arn                    = var.kms_key_arn

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []

    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]

    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn == null ? [] : [var.dead_letter_target_arn]

    content {
      target_arn = dead_letter_config.value
    }
  }

  tracing_config {
    mode = var.tracing_mode
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  tags = local.tags

  depends_on = [aws_cloudwatch_log_group.this]

  lifecycle {
    precondition {
      condition     = !local.is_zip || (var.handler != null && var.runtime != null)
      error_message = "A Zip package needs both handler and runtime."
    }

    precondition {
      condition     = local.is_zip || var.image_uri != null
      error_message = "An Image package needs image_uri."
    }

    precondition {
      condition     = var.filename != null || var.s3_bucket != null || var.image_uri != null
      error_message = "Give the function code: filename, s3_bucket with s3_key, or image_uri."
    }
  }
}

resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrency > 0 ? 1 : 0

  function_name                     = aws_lambda_function.this.function_name
  qualifier                         = aws_lambda_function.this.version
  provisioned_concurrent_executions = var.provisioned_concurrency
}

resource "aws_lambda_event_source_mapping" "this" {
  for_each = var.event_source_mappings

  function_name    = aws_lambda_function.this.arn
  event_source_arn = each.value.event_source_arn
  enabled          = each.value.enabled

  batch_size                         = each.value.batch_size
  maximum_batching_window_in_seconds = each.value.maximum_batching_window_in_seconds
  starting_position                  = each.value.starting_position
  function_response_types            = each.value.function_response_types
  maximum_retry_attempts             = each.value.maximum_retry_attempts
}

resource "aws_lambda_permission" "this" {
  for_each = var.allowed_invoke_principals

  statement_id  = each.key
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = each.value.principal
  source_arn    = each.value.source_arn
}
