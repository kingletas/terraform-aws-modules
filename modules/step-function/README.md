# step-function

A state machine with logging and X-Ray tracing, for orchestrating work that a single function should not.

## Usage

```hcl
module "order_flow" {
  source = "github.com/kingletas/terraform-aws-modules//modules/step-function?ref=v0.1.0"

  name     = "order-fulfilment"
  role_arn = module.order_flow_role.arn

  definition_json = jsonencode({
    Comment = "Fulfil an order"
    StartAt = "Reserve"
    States = {
      Reserve = {
        Type     = "Task"
        Resource = module.reserve.arn
        Next     = "Charge"
        Retry    = [{ ErrorEquals = ["States.TaskFailed"], MaxAttempts = 3 }]
      }
      Charge = {
        Type     = "Task"
        Resource = module.charge.arn
        End      = true
      }
    }
  })
}
```

## STANDARD or EXPRESS is not a tuning choice

- **STANDARD** keeps full execution history for 90 days, runs up to a year, and is billed per state transition. You can open a failed execution and see exactly which state failed and with what.
- **EXPRESS** is billed on duration, is capped at five minutes, and **keeps no execution history at all**. With `log_level = "ERROR"` a failure leaves almost nothing behind.

Choose EXPRESS for high-volume short work, and set `log_level = "ALL"` when you do, or debugging it is guesswork.

## Notes

- `include_execution_data` writes state input and output to CloudWatch. Convenient, and it puts your payloads — including anything sensitive passing between states — into logs.
- The role needs permission for everything the states invoke, and for X-Ray if tracing is on.

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
| [aws_sfn_state_machine.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | State machine name, also used for the log group. | `string` | n/a | yes |
| definition\_json | Amazon States Language definition. Render it with jsonencode or templatefile in the caller. | `string` | n/a | yes |
| role\_arn | Role the state machine runs as. It needs permission for everything the states invoke. | `string` | n/a | yes |
| type | STANDARD keeps full history and is billed per transition. EXPRESS is cheaper at high volume, capped at five minutes, and keeps no history. | `string` | `"STANDARD"` | no |
| log\_level | ALL, ERROR, FATAL or OFF. An EXPRESS workflow keeps no execution history, so ALL is the only way to see what happened. | `string` | `"ERROR"` | no |
| include\_execution\_data | Include state input and output in logs. Convenient for debugging, and it writes your payloads to CloudWatch. | `bool` | `false` | no |
| log\_retention\_days | Days to keep execution logs. | `number` | `365` | no |
| kms\_key\_arn | KMS key encrypting the log group. | `string` | `null` | no |
| tracing\_enabled | Trace executions with X-Ray. | `bool` | `true` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the state machine. |
| name | Name of the state machine. |
| creation\_date | When the state machine was created. |
| log\_group\_name | CloudWatch log group holding execution logs, or null when logging is off. |
<!-- END_TF_DOCS -->
