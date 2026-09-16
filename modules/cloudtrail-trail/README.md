# cloudtrail-trail

A multi-region trail with log file validation, which is the record of who did what in the account.

## Usage

```hcl
module "trail" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudtrail-trail?ref=v0.3.0"

  name           = "platform-audit"
  s3_bucket_name = module.audit_logs.id
  kms_key_arn    = module.kms.arn

  cloudwatch_log_group_arn = module.trail_logs.arn
  cloudwatch_role_arn      = module.trail_role.arn

  insight_types = ["ApiCallRateInsight", "ApiErrorRateInsight"]
}
```

## Why the trail is multi-region

A single-region trail records nothing about the regions you are not watching, which is where unwanted activity tends to appear. Stolen credentials used to run instances in ap-south-1 show up in no trail scoped to us-east-1. `is_multi_region_trail` is on by default.

`include_global_service_events` covers IAM, STS and CloudFront, which are global services and are otherwise not recorded by a regional trail.

## Notes

- **`enable_log_file_validation` is what makes the trail evidence.** It writes digest files so a tampered or deleted log can be detected. Without it, nothing proves the logs are complete and unaltered.
- The S3 bucket policy must already allow the CloudTrail service to write, and a `kms_key_arn` key policy must allow CloudTrail to use the key. This module edits neither.
- **Data events are billed per event, and a busy bucket generates an enormous number.** Scope `resource_values` to prefixes that matter rather than a whole bucket.
- **Management events** (the control-plane calls that change the account) are recorded by default. `management_events_read_write_type` narrows them to `ReadOnly` or `WriteOnly`, and `include_management_events = false` turns them off, which needs at least one data event or the plan fails. Data events switch the trail to advanced event selectors, which replace the default selector, so the module adds a management-events selector alongside them when management events are on.
- Each data event takes its own `read_write_type`: `All`, `ReadOnly` or `WriteOnly`.
- `cloudwatch_log_group_arn` needs `cloudwatch_role_arn`, a role CloudTrail can assume to write to the group. Pass the log group's plain ARN; the module adds the `:*` suffix CloudTrail expects.
- Delivering to CloudWatch Logs is what makes events queryable and usable for alarms. The S3 copy alone is storage.

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
| [aws_cloudtrail.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Trail name. | `string` | n/a | yes |
| s3\_bucket\_name | Bucket receiving log files. Its policy must already allow the CloudTrail service to write. | `string` | n/a | yes |
| s3\_key\_prefix | Prefix inside the bucket. | `string` | `null` | no |
| is\_multi\_region\_trail | Record events from every region. A single-region trail misses activity in the regions you are not watching, which is where it tends to happen. | `bool` | `true` | no |
| is\_organization\_trail | Record every account in the organization. Only valid from the management account. | `bool` | `false` | no |
| include\_global\_service\_events | Include IAM, STS and CloudFront, which are global and otherwise recorded nowhere. | `bool` | `true` | no |
| enable\_log\_file\_validation | Write digest files so a tampered log can be detected. This is what makes the trail evidence. | `bool` | `true` | no |
| kms\_key\_arn | KMS key encrypting log files. The key policy must allow the CloudTrail service. | `string` | `null` | no |
| cloudwatch\_log\_group\_arn | Log group to also deliver events to, which is what makes them queryable and alarmable. Null skips it. | `string` | `null` | no |
| cloudwatch\_role\_arn | Role CloudTrail uses to write to the log group. Required with cloudwatch\_log\_group\_arn. | `string` | `null` | no |
| sns\_topic\_name | SNS topic notified when a new log file arrives. | `string` | `null` | no |
| data\_events | Data event selectors keyed by a stable name, for object-level S3 or Lambda invocation logging. read\_write\_type is All, ReadOnly or WriteOnly. These are billed per event and a busy bucket generates a great many. | <pre>map(object({<br/>    resource_type   = string<br/>    resource_values = list(string)<br/>    read_write_type = optional(string, "All")<br/>  }))</pre> | `{}` | no |
| include\_management\_events | Record management events, the control-plane calls that change the account. Turning this off leaves only the data events. | `bool` | `true` | no |
| management\_events\_read\_write\_type | Which management events to record: All, ReadOnly or WriteOnly. | `string` | `"All"` | no |
| insight\_types | Insight types to detect unusual activity: ApiCallRateInsight, ApiErrorRateInsight. | `list(string)` | `[]` | no |
| tags | Tags applied to the trail. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the trail. |
| name | Name of the trail. |
| home\_region | Region the trail was created in, which is where a multi-region trail is managed from. |
<!-- END_TF_DOCS -->
