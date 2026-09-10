# sns-topic

A topic and its subscriptions, for fanning one message out to queues, functions and people.

## Usage

```hcl
module "alerts" {
  source = "github.com/kingletas/terraform-aws-modules//modules/sns-topic?ref=v0.1.0"

  name       = "platform-alerts"
  kms_key_id = module.kms.key_id

  subscriptions = {
    oncall_email = {
      protocol = "email"
      endpoint = "oncall@example.com"
    }

    processor = {
      protocol             = "sqs"
      endpoint             = module.queue.arn
      raw_message_delivery = true
    }
  }
}
```

## Notes

- **An email or SMS subscription does not deliver until its owner confirms it.** Terraform reports the subscription as created either way, so a new alert route can look wired up and be silently inert.
- `raw_message_delivery` sends the message body alone. Without it, an SQS consumer receives the body wrapped in SNS metadata.
- A FIFO topic can only be subscribed to by FIFO queues.

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
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Topic name. A FIFO topic gets the .fifo suffix added for you. | `string` | n/a | yes |
| display\_name | Name shown as the sender on SMS and email deliveries. | `string` | `null` | no |
| fifo\_topic | Make this a FIFO topic. Only FIFO queues may subscribe. | `bool` | `false` | no |
| content\_based\_deduplication | Deduplicate FIFO messages on a hash of the body. Ignored for a standard topic. | `bool` | `false` | no |
| kms\_key\_id | KMS key for encryption at rest. Null leaves the topic unencrypted, which SNS allows and an audit will not. | `string` | `null` | no |
| subscriptions | Subscriptions keyed by a stable name. Email and SMS endpoints must be confirmed by their owner before they deliver. | <pre>map(object({<br/>    protocol               = string<br/>    endpoint               = string<br/>    raw_message_delivery   = optional(bool, false)<br/>    filter_policy          = optional(string)<br/>    filter_policy_scope    = optional(string)<br/>    endpoint_auto_confirms = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| delivery\_policy\_json | Delivery retry policy as JSON. Null uses the SNS defaults. | `string` | `null` | no |
| attach\_policy | Attach policy\_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply. | `bool` | `false` | no |
| policy\_json | Topic policy document. Null leaves publishing to IAM identities with explicit permission. | `string` | `null` | no |
| tags | Tags applied to the topic. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the topic, which is what a publisher and an alarm action need. |
| id | ID of the topic, which is the same as its ARN. |
| name | Name of the topic, including the .fifo suffix where one applies. |
| subscription\_arns | Subscription ARNs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
