resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms

  alarm_name        = each.key
  alarm_description = each.value.description
  actions_enabled   = var.actions_enabled

  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  treat_missing_data  = each.value.treat_missing_data

  # A maths expression and a plain metric are mutually exclusive on the same alarm.
  metric_name        = each.value.metric_query == null ? each.value.metric_name : null
  namespace          = each.value.metric_query == null ? each.value.namespace : null
  dimensions         = each.value.metric_query == null ? each.value.dimensions : null
  period             = each.value.metric_query == null ? each.value.period : null
  statistic          = each.value.metric_query == null && each.value.extended_statistic == null ? each.value.statistic : null
  extended_statistic = each.value.metric_query == null ? each.value.extended_statistic : null
  unit               = each.value.unit

  dynamic "metric_query" {
    for_each = coalesce(each.value.metric_query, [])

    content {
      id          = metric_query.value.id
      expression  = metric_query.value.expression
      label       = metric_query.value.label
      return_data = metric_query.value.return_data

      dynamic "metric" {
        for_each = metric_query.value.metric_name == null ? [] : [metric_query.value]

        content {
          metric_name = metric.value.metric_name
          namespace   = metric.value.namespace
          dimensions  = metric.value.dimensions
          period      = metric.value.period
          stat        = metric.value.stat
        }
      }
    }
  }

  alarm_actions             = coalesce(each.value.alarm_actions, var.default_alarm_actions)
  ok_actions                = coalesce(each.value.ok_actions, var.default_ok_actions)
  insufficient_data_actions = coalesce(each.value.insufficient_data_actions, [])

  tags = merge(var.tags, { Name = each.key })
}
