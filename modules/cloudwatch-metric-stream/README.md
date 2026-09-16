# cloudwatch-metric-stream

Pushes CloudWatch metrics to a delivery stream as they arrive, instead of something polling for them.

## Usage

```hcl
module "metric_stream" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudwatch-metric-stream?ref=v0.3.0"

  name         = "to-vendor"
  role_arn     = module.metric_stream_role.arn
  firehose_arn = module.metrics_to_vendor.arn

  include_namespaces = {
    "AWS/EC2"            = []
    "AWS/RDS"            = []
    "AWS/ApplicationELB" = ["RequestCount", "TargetResponseTime", "HTTPCode_Target_5XX_Count"]
  }

  statistics_configurations = {
    latency = {
      additional_statistics = ["p95", "p99"]
      metrics               = [{ namespace = "AWS/ApplicationELB", metric_name = "TargetResponseTime" }]
    }
  }
}
```

## Streaming instead of polling

The usual way a monitoring vendor reads CloudWatch is to call `GetMetricData` on a schedule, per region, per namespace. That costs an API call per poll, it lags by however long the interval is, and the lag is worst exactly when a lot is happening.

A metric stream pushes instead. Metrics arrive within a couple of minutes of being published, the cost moves from API calls to a charge per metric update, and the vendor stops needing broad read permissions across the account.

Polling is cheaper when you watch few metrics. Streaming is cheaper and faster when you watch many. **The filters below decide which side you are on**, so set them deliberately rather than streaming everything and finding out on the bill.

## An include list or an exclude list, never both

`include_namespaces` streams only what it names. `exclude_namespaces` streams everything except what it names. AWS accepts one or the other, and the module refuses both at plan.

Prefer the include list. With an exclude list, every namespace AWS adds later starts streaming, and being charged for, without anyone deciding. With neither list set, the stream carries every namespace.

An empty list against a namespace means every metric in it. A populated one names the metrics, which keeps a busy namespace like `AWS/ApplicationELB` or `AWS/Usage` to the metrics you actually read.

## Percentiles are charged per statistic

A stream carries the four default statistics with no extra charge: minimum, maximum, sum and sample count. Anything else, `p95` and `p99` included, is billed per additional statistic per metric.

That is why `statistics_configurations` names individual metrics rather than namespaces. A `p99` on the one latency metric that matters costs almost nothing. A `p99` across a namespace costs it on every metric in it, including the ones nobody reads.

## Notes

- **The role is yours to build.** CloudWatch assumes it to write to the delivery stream, and it needs `firehose:PutRecord` and `firehose:PutRecordBatch` on that stream alone. The [`iam-role`](../iam-role) module builds it with `streams.metrics.cloudwatch.amazonaws.com` in `trusted_services`.
- **A stream is per region.** Metrics from another region need a stream there too, and a delivery stream there to write to.
- `output_format` defaults to `json` because most vendors accept it. The OpenTelemetry formats are smaller on the wire and carry resource attributes; check what the receiving service parses before switching.

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
| [aws_cloudwatch_metric_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_stream) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Metric stream name, unique within the account and region. | `string` | n/a | yes |
| role\_arn | Role CloudWatch assumes to write to the delivery stream. It needs firehose:PutRecord and firehose:PutRecordBatch on that stream. | `string` | n/a | yes |
| firehose\_arn | Delivery stream metrics are written to. Build it with the kinesis-firehose module. | `string` | n/a | yes |
| output\_format | Wire format. json is what most vendors accept; the OpenTelemetry formats are smaller and carry resource attributes. | `string` | `"json"` | no |
| include\_namespaces | Namespaces to stream, keyed by namespace, each an explicit list of metric names or an empty list for every metric in it. Set this or exclude\_namespaces, not both. | `map(list(string))` | `{}` | no |
| exclude\_namespaces | Namespaces to leave out, keyed the same way. Everything else streams. Set this or include\_namespaces, not both. | `map(list(string))` | `{}` | no |
| statistics\_configurations | Extra statistics beyond the default four, keyed by a name you choose. Percentiles are charged per statistic, so name the metrics that need them rather than a whole namespace. | <pre>map(object({<br/>    additional_statistics = list(string)<br/>    metrics = list(object({<br/>      namespace   = string<br/>      metric_name = string<br/>    }))<br/>  }))</pre> | `{}` | no |
| include\_linked\_accounts\_metrics | Also stream metrics shared into this account by a monitoring account link. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the metric stream. |
| name | Name of the metric stream. |
| state | Whether the stream is running. |
<!-- END_TF_DOCS -->
