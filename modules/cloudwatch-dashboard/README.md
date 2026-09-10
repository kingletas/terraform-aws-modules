# cloudwatch-dashboard

A dashboard whose widgets are laid out for you, so adding one does not mean recomputing every coordinate.

## Usage

```hcl
module "dashboard" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudwatch-dashboard?ref=v0.1.0"

  name = "platform-overview"

  widgets = [
    {
      type     = "text"
      width    = 24
      height   = 2
      markdown = "# Platform\nRequest volume, latency and errors."
    },
    {
      title   = "Requests"
      metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.arn_suffix]]
      stat    = "Sum"
    },
    {
      title   = "p99 latency"
      metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.arn_suffix]]
      stat    = "p99"

      annotations_horizontal = [{ value = 1, label = "SLO", color = "#d62728" }]
    },
  ]
}
```

## Layout

The grid is 24 columns wide. Leave `x` and `y` unset and widgets are placed left to right in order, wrapping when the row fills — so a 12-wide widget puts two per row. Set `x` and `y` to take over placement entirely.

## Notes

- **A horizontal annotation is what makes a graph readable.** A latency chart without the SLO line on it asks the reader to hold the number in their head and do the comparison themselves.
- `stat` accepts percentiles such as `p99`. An average latency hides exactly the requests you care about.
- A `log` widget runs a Logs Insights query, which is billed per scan.

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
| widgets | Widgets in reading order. Leave x and y unset and the module lays them out left to right, wrapping at 24 columns. | <pre>list(object({<br/>    type   = optional(string, "metric")<br/>    title  = optional(string)<br/>    width  = optional(number, 12)<br/>    height = optional(number, 6)<br/>    x      = optional(number)<br/>    y      = optional(number)<br/><br/>    # A JSON-encoded CloudWatch metric array, from jsonencode in the caller.<br/>    # The array is heterogeneous by design — dimension pairs as strings, then an<br/>    # optional options object overriding stat or colour for that one line — and<br/>    # no Terraform object type can hold that alongside the rest of a widget.<br/>    metrics_json = optional(string)<br/>    view         = optional(string, "timeSeries")<br/>    stacked      = optional(bool, false)<br/>    stat         = optional(string, "Average")<br/>    period       = optional(number, 300)<br/>    region       = optional(string)<br/><br/>    yaxis_left_min = optional(number)<br/>    yaxis_left_max = optional(number)<br/><br/>    annotations_horizontal = optional(list(object({<br/>      value = number<br/>      label = optional(string)<br/>      color = optional(string)<br/>    })))<br/><br/>    markdown = optional(string)<br/><br/>    log_query = optional(string)<br/>  }))</pre> | n/a | yes |
| default\_region | Region a widget reads metrics from when it names none. Null uses the provider's region. | `string` | `null` | no |
| default\_period | Aggregation period in seconds for widgets that name none. | `number` | `300` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| name | Name of the dashboard. |
| arn | ARN of the dashboard. |
| url | Console URL for the dashboard. |
<!-- END_TF_DOCS -->
