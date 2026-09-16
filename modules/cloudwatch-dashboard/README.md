# cloudwatch-dashboard

A dashboard whose widgets CloudWatch lays out for you, so adding one does not mean recomputing every coordinate.

## Usage

```hcl
module "dashboard" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudwatch-dashboard?ref=v0.5.0"

  name = "platform-overview"

  widgets = [
    {
      type     = "text"
      width    = 24
      height   = 2
      markdown = "# Platform\nRequest volume, latency and errors."
    },
    {
      title        = "Requests"
      metrics_json = jsonencode([["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.arn_suffix]])
      stat         = "Sum"
    },
    {
      title        = "p99 latency"
      metrics_json = jsonencode([["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.arn_suffix]])
      stat         = "p99"

      annotations_horizontal = [{ value = 1, label = "SLO", color = "#d62728" }]
    },
  ]
}
```

## Layout

The grid is 24 columns wide. Leave `x` and `y` unset and the module leaves both out of the dashboard body, so CloudWatch places each widget in the next free position: left to right in order, wrapping to a new row when the next widget would not fit. Two 12-wide widgets share a row, and a 12-wide widget followed by two 8-wide ones puts the second 8 on the next row. Set `x` and `y` together to place a widget yourself. The module refuses `x` without `y` (or the reverse), and a placed widget whose `x` plus `width` runs past column 24.

## Notes

- **A horizontal annotation is what makes a graph readable.** A latency chart without the SLO line on it leaves the reader to remember the target and compare by eye.
- `stat` accepts percentiles such as `p99`. An average latency hides exactly the requests you care about.
- A `log` widget runs the Logs Insights query in `log_query`, which is billed by the data it scans.
- `default_region` sets the region for widgets that name none, and defaults to the provider's region.
- The `url` output is null in a partition with no known console hostname.

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
| [aws_cloudwatch_dashboard.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Dashboard name. | `string` | n/a | yes |
| widgets | Widgets in reading order. Leave x and y unset and CloudWatch places them left to right, wrapping at 24 columns. Set both to place a widget yourself. | <pre>list(object({<br/>    type   = optional(string, "metric")<br/>    title  = optional(string)<br/>    width  = optional(number, 12)<br/>    height = optional(number, 6)<br/>    x      = optional(number)<br/>    y      = optional(number)<br/><br/>    # A JSON-encoded CloudWatch metric array, from jsonencode in the caller.<br/>    # The array is heterogeneous by design (dimension pairs as strings, then an<br/>    # optional options object overriding stat or colour for that one line), and<br/>    # no Terraform object type can hold that alongside the rest of a widget.<br/>    metrics_json = optional(string)<br/>    view         = optional(string, "timeSeries")<br/>    stacked      = optional(bool, false)<br/>    stat         = optional(string, "Average")<br/>    period       = optional(number, 300)<br/>    region       = optional(string)<br/><br/>    yaxis_left_min = optional(number)<br/>    yaxis_left_max = optional(number)<br/><br/>    annotations_horizontal = optional(list(object({<br/>      value = number<br/>      label = optional(string)<br/>      color = optional(string)<br/>    })))<br/><br/>    markdown = optional(string)<br/><br/>    log_query = optional(string)<br/>  }))</pre> | n/a | yes |
| default\_region | Region a widget reads metrics from when it names none. Null uses the provider's region. | `string` | `null` | no |
| default\_period | Aggregation period in seconds for widgets that name none. | `number` | `300` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| name | Name of the dashboard. |
| arn | ARN of the dashboard. |
| url | Console URL for the dashboard, or null in a partition with no known console hostname. |
<!-- END_TF_DOCS -->
