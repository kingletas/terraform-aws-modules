locals {
  suffix     = var.fifo_topic ? ".fifo" : ""
  topic_name = format("%s%s", trimsuffix(var.name, ".fifo"), local.suffix)
}

resource "aws_sns_topic" "this" {
  name                        = local.topic_name
  display_name                = var.display_name
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null

  kms_master_key_id = var.kms_key_id
  delivery_policy   = var.delivery_policy_json

  tags = merge(var.tags, { Name = local.topic_name })
}

resource "aws_sns_topic_policy" "this" {
  count = var.attach_policy ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = var.policy_json
}

resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  raw_message_delivery   = each.value.raw_message_delivery
  filter_policy          = each.value.filter_policy
  filter_policy_scope    = each.value.filter_policy_scope
  endpoint_auto_confirms = each.value.endpoint_auto_confirms
}
