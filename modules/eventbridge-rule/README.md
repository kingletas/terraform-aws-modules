# eventbridge-rule

A rule and its targets, on a schedule or an event pattern.

## Usage

```hcl
module "nightly" {
  source = "github.com/kingletas/terraform-aws-modules//modules/eventbridge-rule?ref=v0.7.0"

  name                = "nightly-reconciliation"
  schedule_expression = "cron(0 3 * * ? *)"

  targets = {
    reconcile = {
      arn             = module.reconcile.arn
      dead_letter_arn = module.failed_events.arn
    }
  }
}
```

## Always set a dead letter queue

When EventBridge cannot deliver to a target it retries, and then it **drops the event silently**. There is no error, no metric anyone watches by default, and no record of what was lost.

A `dead_letter_arn` turns that into a message sitting in a queue you can inspect. For a nightly job, it is the difference between noticing tomorrow and noticing at quarter end.

## Notes

- **Schedule expressions are always UTC.** A `cron(0 3 * * ? *)` job does not follow daylight saving, so it moves an hour relative to local time twice a year.
- A Lambda target also needs an invoke permission with this rule's ARN as `source_arn`. The `lambda-function` module's `allowed_invoke_principals` does that side.
- `input_transformer` reshapes the event before the target sees it, which avoids a Lambda whose only job is reformatting. A target sets at most one of `input`, `input_path` and `input_transformer`, and the plan refuses more.

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
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Rule name. | `string` | n/a | yes |
| description | What this rule reacts to. | `string` | `null` | no |
| event\_bus\_name | Bus the rule listens on. Null uses the account default bus. | `string` | `null` | no |
| schedule\_expression | cron or rate expression, in UTC. Set this or event\_pattern, not both. | `string` | `null` | no |
| event\_pattern\_json | Event pattern as JSON. Set this or schedule\_expression, not both. | `string` | `null` | no |
| enabled | Whether the rule fires. | `bool` | `true` | no |
| targets | Targets keyed by a stable name. Each shapes its payload with at most one of input, input\_path or input\_transformer. Always set a dead\_letter\_arn, or a failed delivery is lost silently. | <pre>map(object({<br/>    arn      = string<br/>    role_arn = optional(string)<br/><br/>    input      = optional(string)<br/>    input_path = optional(string)<br/>    input_transformer = optional(object({<br/>      input_paths    = map(string)<br/>      input_template = string<br/>    }))<br/><br/>    dead_letter_arn        = optional(string)<br/>    maximum_retry_attempts = optional(number, 3)<br/>    maximum_event_age      = optional(number, 3600)<br/><br/>    sqs_message_group_id = optional(string)<br/><br/>    ecs_task_definition_arn = optional(string)<br/>    ecs_task_count          = optional(number, 1)<br/>    ecs_launch_type         = optional(string, "FARGATE")<br/>    ecs_subnet_ids          = optional(list(string))<br/>    ecs_security_group_ids  = optional(list(string))<br/>    ecs_assign_public_ip    = optional(bool, false)<br/>  }))</pre> | n/a | yes |
| tags | Tags applied to the rule. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the rule, which a Lambda permission uses as its source\_arn. |
| name | Name of the rule. |
| target\_ids | Target IDs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
