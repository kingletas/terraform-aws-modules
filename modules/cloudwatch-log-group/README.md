# cloudwatch-log-group

A log group with retention, plus the metric and subscription filters that make its contents useful.

## Usage

```hcl
module "app_logs" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudwatch-log-group?ref=v0.7.0"

  name           = "/platform/api"
  retention_days = 90
  kms_key_arn    = module.kms.arn

  metric_filters = {
    unhandled_exceptions = {
      pattern          = "{ $.level = \"ERROR\" && $.kind = \"unhandled\" }"
      metric_name      = "UnhandledExceptions"
      metric_namespace = "Platform/API"
      default_value    = 0
    }
  }
}
```

## A metric filter is how a log line becomes an alarm

CloudWatch cannot alarm on log text. A metric filter counts matching lines into a metric, and that metric is what an alarm watches.

**Set `default_value = 0`.** Without it, the filter publishes nothing when there are no matches, so the metric has gaps rather than zeroes. An alarm over a gap then depends entirely on `treat_missing_data`, which is easy to get wrong on an error alert.

## Notes

- `retention_days = 0` keeps logs forever. Storage cost then only grows. The module defaults to 365 days.
- Encrypting with a key needs `logs.<region>.amazonaws.com` in that key's policy, or the group cannot be created, and the error does not mention the key.
- `INFREQUENT_ACCESS` is cheaper and supports far less: no metric filters, no Live Tail, and limited Logs Insights queries.
- `skip_destroy` keeps the logs when Terraform removes the group.

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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_metric_filter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_log_subscription_filter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_subscription_filter) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Log group name, conventionally a path such as /aws/service/thing. | `string` | n/a | yes |
| retention\_days | Days to keep logs. Zero keeps them forever, which is a bill that only grows. | `number` | `365` | no |
| kms\_key\_arn | KMS key encrypting the group. The key policy must allow the logs service principal for this region. | `string` | `null` | no |
| log\_class | STANDARD for logs you query and alarm on. INFREQUENT\_ACCESS is cheaper and supports far less. | `string` | `"STANDARD"` | no |
| skip\_destroy | Leave the group in place when Terraform destroys it, keeping the logs. | `bool` | `false` | no |
| metric\_filters | Metric filters keyed by a stable name. This is how a log line becomes a number an alarm can watch. | <pre>map(object({<br/>    pattern          = string<br/>    metric_name      = string<br/>    metric_namespace = string<br/>    metric_value     = optional(string, "1")<br/>    default_value    = optional(number)<br/>    unit             = optional(string)<br/>  }))</pre> | `{}` | no |
| subscription\_filters | Subscription filters keyed by a stable name, for shipping logs onward to Firehose, Lambda or OpenSearch. | <pre>map(object({<br/>    pattern         = string<br/>    destination_arn = string<br/>    role_arn        = optional(string)<br/>    distribution    = optional(string, "ByLogStream")<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to the log group. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| name | Name of the log group. |
| arn | ARN of the log group, with the :* suffix AWS appends. |
| metric\_filter\_ids | Metric filter IDs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
