locals {
  service_grant = length(var.sending_services) > 0

  suffix     = var.fifo_queue ? ".fifo" : ""
  queue_name = format("%s%s", trimsuffix(var.name, ".fifo"), local.suffix)
  dlq_name   = format("%s-dlq%s", trimsuffix(var.name, ".fifo"), local.suffix)

  dlq_enabled = coalesce(var.dead_letter_queue.enabled, true)
}

resource "aws_sqs_queue" "dead_letter" {
  count = local.dlq_enabled ? 1 : 0

  name                        = local.dlq_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  message_retention_seconds = var.dead_letter_queue.message_retention_seconds
  kms_master_key_id         = var.kms_key_id
  sqs_managed_sse_enabled   = var.kms_key_id == null ? true : null

  tags = merge(var.tags, { Name = local.dlq_name })
}

resource "aws_sqs_queue" "this" {
  name                        = local.queue_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds

  kms_master_key_id       = var.kms_key_id
  sqs_managed_sse_enabled = var.kms_key_id == null ? true : null

  redrive_policy = local.dlq_enabled ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
    maxReceiveCount     = var.dead_letter_queue.max_receive_count
  }) : null

  tags = merge(var.tags, { Name = local.queue_name })
}

# Only this queue may send to its own dead letter queue.
resource "aws_sqs_queue_redrive_allow_policy" "dead_letter" {
  count = local.dlq_enabled ? 1 : 0

  queue_url = aws_sqs_queue.dead_letter[0].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}

data "aws_caller_identity" "current" {}

# The named services may send only from this account, and only from the named source ARNs when there are any.
data "aws_iam_policy_document" "this" {
  count = local.service_grant ? 1 : 0

  source_policy_documents = var.attach_policy ? [var.policy_json] : []

  statement {
    sid       = "AllowServiceSend"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "Service"
      identifiers = var.sending_services
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    dynamic "condition" {
      for_each = length(var.sending_source_arns) > 0 ? [var.sending_source_arns] : []

      content {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = condition.value
      }
    }
  }
}

resource "aws_sqs_queue_policy" "this" {
  count = var.attach_policy || local.service_grant ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = local.service_grant ? data.aws_iam_policy_document.this[0].json : var.policy_json
}
