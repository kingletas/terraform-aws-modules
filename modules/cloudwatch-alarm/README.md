# cloudwatch-alarm

Alarms declared as a set, including metric maths, with a shared default action.

## Usage

```hcl
module "alarms" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudwatch-alarm?ref=v0.3.0"

  default_alarm_actions = [module.alerts.arn]
  default_ok_actions    = [module.alerts.arn]

  alarms = {
    api-5xx-rate = {
      description         = "More than 1% of API responses are 5xx"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 1
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      treat_missing_data  = "notBreaching"

      metric_query = [
        { id = "errors", metric_name = "HTTPCode_Target_5XX_Count", namespace = "AWS/ApplicationELB", stat = "Sum", dimensions = { LoadBalancer = module.alb.arn_suffix } },
        { id = "total", metric_name = "RequestCount", namespace = "AWS/ApplicationELB", stat = "Sum", dimensions = { LoadBalancer = module.alb.arn_suffix } },
        { id = "rate", expression = "errors / total * 100", label = "5xx rate", return_data = true },
      ]
    }
  }
}
```

## Alarm on a rate, not a count

An alarm on "more than 50 errors" fires during a traffic spike where the error *rate* never moved, and stays quiet at 3am when 40 of your 45 requests fail. Neither is the thing you wanted to know.

`metric_query` is what lets you divide one metric by another and alarm on the result. Exactly one query in the list must set `return_data = true`: that is the series the alarm evaluates. The module checks this at plan.

## Notes

- **`treat_missing_data` decides what silence means.** A queue that stops receiving produces no datapoints, and with the default `missing` the alarm moves to `INSUFFICIENT_DATA` rather than alarming. Choose deliberately: `notBreaching` for a metric that legitimately goes quiet, `breaching` for a heartbeat.
- `datapoints_to_alarm` below `evaluation_periods` gives an M-of-N alarm, which rides out a single bad interval without ignoring a real trend.
- An alarm with no `alarm_actions` or `ok_actions` of its own uses `default_alarm_actions` and `default_ok_actions`. **Set the OK actions.** An alarm that never says it recovered leaves someone checking by hand.
- **The evaluation window is capped.** `period` times `evaluation_periods` may not exceed one day (86400 seconds), or one hour for a high-resolution period under 60 seconds. For a `metric_query` alarm the check uses each metric query's `period`. The module refuses a longer window at plan, where CloudWatch would refuse it at apply.
- `actions_enabled = false` silences every alarm in the module while you tune thresholds, without deleting them.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_metric_alarm.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| alarms | Alarms keyed by alarm name. Give each one either metric\_name with namespace, or a metric\_query for a maths expression. | <pre>map(object({<br/>    metric_name = optional(string)<br/>    namespace   = optional(string)<br/>    dimensions  = optional(map(string), {})<br/><br/>    comparison_operator = string<br/>    threshold           = optional(number)<br/>    evaluation_periods  = optional(number, 2)<br/>    datapoints_to_alarm = optional(number)<br/>    period              = optional(number, 300)<br/>    statistic           = optional(string, "Average")<br/>    extended_statistic  = optional(string)<br/>    unit                = optional(string)<br/><br/>    description        = optional(string)<br/>    treat_missing_data = optional(string, "missing")<br/><br/>    metric_query = optional(list(object({<br/>      id          = string<br/>      expression  = optional(string)<br/>      label       = optional(string)<br/>      return_data = optional(bool, false)<br/><br/>      metric_name = optional(string)<br/>      namespace   = optional(string)<br/>      dimensions  = optional(map(string), {})<br/>      period      = optional(number, 300)<br/>      stat        = optional(string, "Average")<br/>    })))<br/><br/>    alarm_actions             = optional(list(string))<br/>    ok_actions                = optional(list(string))<br/>    insufficient_data_actions = optional(list(string))<br/>  }))</pre> | n/a | yes |
| default\_alarm\_actions | Actions used by any alarm that names none of its own. Usually one SNS topic. | `list(string)` | `[]` | no |
| default\_ok\_actions | Recovery actions used by any alarm that names none of its own. An alarm that never tells you it cleared is half a signal. | `list(string)` | `[]` | no |
| actions\_enabled | Whether alarms fire their actions. Turn off while tuning a threshold rather than deleting the alarm. | `bool` | `true` | no |
| tags | Tags applied to every alarm. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arns | Alarm ARNs, keyed by alarm name. |
| names | Alarm names, which is also the map's keys. |
<!-- END_TF_DOCS -->
