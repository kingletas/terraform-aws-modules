# sqs-queue

A queue and its dead letter queue, because a queue without one redelivers a poison message forever.

## Usage

```hcl
module "orders" {
  source = "github.com/kingletas/terraform-aws-modules//modules/sqs-queue?ref=v0.3.0"

  name                       = "order-events"
  visibility_timeout_seconds = 300

  dead_letter_queue = {
    max_receive_count = 3
  }

  tags = { Environment = "production" }
}
```

## The setting that causes most trouble

`visibility_timeout_seconds` is how long a received message is hidden from other consumers. Set it below your worst-case processing time and the message reappears while the first worker is still on it, so the work happens twice. For a Lambda consumer, AWS asks for at least six times the function timeout.

## Notes

- A FIFO queue takes the `.fifo` suffix automatically, so you do not need to add it to `name`.
- `receive_wait_time_seconds` defaults to 20, which is long polling. Zero means short polling, which bills you for empty receives.
- The dead letter queue accepts redrives from this queue and no other.
- **An AWS service that sends to the queue needs a queue policy grant.** List it in `sending_services`, such as `["events.amazonaws.com"]`. The grant is limited to sources in this account by `aws:SourceAccount`, and to `sending_source_arns` when you set it. It is merged with `policy_json` when `attach_policy` is on. The Sid `AllowServiceSend` is reserved.

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
| [aws_sqs_queue.dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_redrive_allow_policy.dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_redrive_allow_policy) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Queue name. A FIFO queue gets the .fifo suffix added for you. | `string` | n/a | yes |
| fifo\_queue | Make this a FIFO queue: ordered, exactly-once, and lower throughput. | `bool` | `false` | no |
| content\_based\_deduplication | Deduplicate FIFO messages on a hash of the body instead of an explicit deduplication ID. | `bool` | `false` | no |
| visibility\_timeout\_seconds | How long a received message is hidden from other consumers. Set it above your worst-case processing time or the message is delivered twice. | `number` | `30` | no |
| message\_retention\_seconds | How long an unconsumed message survives before SQS drops it. | `number` | `345600` | no |
| receive\_wait\_time\_seconds | Long-poll wait. Above zero cuts empty receives and the bill with them. | `number` | `20` | no |
| max\_message\_size | Largest message accepted, in bytes. | `number` | `262144` | no |
| delay\_seconds | Delay before a new message becomes visible. | `number` | `0` | no |
| kms\_key\_id | KMS key for encryption at rest. Null uses the SQS-managed key, which is still encryption. | `string` | `null` | no |
| dead\_letter\_queue | Dead letter queue for messages that keep failing. On by default, because without one a poison message is redelivered forever. | <pre>object({<br/>    enabled                   = optional(bool, true)<br/>    max_receive_count         = optional(number, 5)<br/>    message_retention_seconds = optional(number, 1209600)<br/>  })</pre> | `{}` | no |
| attach\_policy | Attach policy\_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply. | `bool` | `false` | no |
| policy\_json | Queue policy document. Null leaves the queue reachable only by IAM identities with explicit permission. | `string` | `null` | no |
| sending\_services | Service principals allowed to send to the queue, such as cloudwatch.amazonaws.com, limited to this account by aws:SourceAccount. Merged into policy\_json when attach\_policy is on; the Sid AllowServiceSend is reserved. | `list(string)` | `[]` | no |
| sending\_source\_arns | Source ARNs the sending\_services are further limited to, by aws:SourceArn. Empty allows any source in this account. | `list(string)` | `[]` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | URL of the queue, which is what a client sends to. |
| arn | ARN of the queue, for IAM policies and event source mappings. |
| name | Name of the queue, including the .fifo suffix where one applies. |
| dead\_letter\_queue\_arn | ARN of the dead letter queue, or null when it is disabled. |
| dead\_letter\_queue\_url | URL of the dead letter queue, or null when it is disabled. |
<!-- END_TF_DOCS -->
