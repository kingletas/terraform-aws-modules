locals {
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

resource "aws_sqs_queue_policy" "this" {
  count = var.attach_policy ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = var.policy_json
}
