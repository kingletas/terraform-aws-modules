resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_days == 0 ? null : var.retention_days
  kms_key_id        = var.kms_key_arn
  log_group_class   = var.log_class
  skip_destroy      = var.skip_destroy

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = var.metric_filters

  name           = each.key
  log_group_name = aws_cloudwatch_log_group.this.name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.metric_namespace
    value         = each.value.metric_value
    default_value = each.value.default_value
    unit          = each.value.unit
  }
}

resource "aws_cloudwatch_log_subscription_filter" "this" {
  for_each = var.subscription_filters

  name            = each.key
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = each.value.pattern
  destination_arn = each.value.destination_arn
  role_arn        = each.value.role_arn
  distribution    = each.value.distribution
}
