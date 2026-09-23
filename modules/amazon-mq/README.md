# amazon-mq

A managed RabbitMQ or ActiveMQ broker, private to your VPC, encrypted at rest.

## Usage

```hcl
module "broker" {
  source = "github.com/kingletas/terraform-aws-modules//modules/amazon-mq?ref=v0.6.0"

  name           = "orders"
  engine_version = "3.13"

  deployment_mode    = "CLUSTER_MULTI_AZ"
  host_instance_type = "mq.m5.large"
  subnet_ids         = slice(values(module.vpc.private_subnet_ids), 0, 2)
  security_group_ids = [module.broker_sg.id]

  users = {
    app = { password = var.broker_password }
  }

  maintenance_window = { day_of_week = "SUNDAY", time_of_day = "04:00" }
}
```

## The password is in Terraform state, and there is no way around it

A database in this library can hand its password to AWS with `manage_master_password`, so Terraform never sees it. **Amazon MQ has no equivalent.** The broker takes its users at creation, in the API call, which means the password is in the plan and in the state file.

What to do about it:

- Keep the value out of your configuration. Generate it with [`secrets-manager-secret`](../secrets-manager-secret) and pass the secret's value in, so the secret is the record and Terraform holds a copy rather than the original.
- Treat the state file as a credential store, which it already is. Encrypted bucket, restricted access, no plain local state.
- **Rotating a broker password is a Terraform change**, not an out-of-band one. Plan it, and read the plan, because some broker changes restart the broker.

## What each engine actually supports

The two engines share a resource and very little else. The module checks the deployment mode, subnet count, user count, storage type, audit log and KMS key against the engine at plan, so a mismatch fails before anything is created rather than part way through an apply.

| | RabbitMQ | ActiveMQ |
|---|---|---|
| Deployment modes | `SINGLE_INSTANCE`, `CLUSTER_MULTI_AZ` (three nodes) | `SINGLE_INSTANCE`, `ACTIVE_STANDBY_MULTI_AZ` (a pair) |
| Users in Terraform | exactly one | as many as you like |
| Further users | the RabbitMQ management interface, not AWS | Terraform |
| Console access and groups | not applicable | per user |
| Storage | EBS | EBS or EFS |
| Customer managed KMS key | no, AWS-owned key only | yes |
| Audit log | none | optional |

**A RabbitMQ cluster is three nodes and one endpoint.** Going from `SINGLE_INSTANCE` to `CLUSTER_MULTI_AZ` is a replacement, not a resize, so decide before there are queues in it.

## Two things that cause an unplanned outage

**A broker change can restart the broker, and a restart drops every connection.** `apply_immediately` is false so that a change waits for the maintenance window. Set it true only when you know what the change does, and know that clients will reconnect.

**`maintenance_window` defaults to null, which lets AWS choose.** AWS then picks a weekly window for you and restarts the broker in it for a minor upgrade. Set one at a time that suits your traffic.

`auto_minor_version_upgrade` is on because AWS publishes a deprecation schedule for engine minor versions, and a broker left on a deprecated one is eventually upgraded anyway. It is better to take that upgrade in a window you chose.

## Notes

- **`publicly_accessible` is false.** A broker with a public endpoint is one credential away from being someone else's, and the credential is in the state file.
- `kms_key_arn = null` means the AWS-owned key. That is still encryption at rest, but not a key whose access you can audit or revoke.
- **A customer managed key is ActiveMQ only.** RabbitMQ brokers always use the AWS-owned key, so the module refuses `kms_key_arn` on RabbitMQ at plan.
- **A broker password is 12 to 250 characters, with at least four different characters, and no comma, colon or equals sign.** The module checks all of these at plan.
- The `mq.t3.micro` default is for development. RabbitMQ will not form a cluster on it.
- `endpoints` is flattened across every instance. RabbitMQ publishes one `amqps` endpoint per node. ActiveMQ publishes five per node, one per wire protocol, so read the one your client speaks rather than the first in the list.

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
| [aws_mq_broker.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/mq_broker) | resource |
| [aws_mq_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/mq_configuration) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Broker name, unique within the account and region. | `string` | n/a | yes |
| engine\_type | RabbitMQ or ActiveMQ. The two differ in deployment modes, users and storage, and this module validates each against the engine. | `string` | `"RabbitMQ"` | no |
| engine\_version | Engine version, such as 3.13. AWS deprecates old minors on a published schedule, so pin one you have tested. | `string` | n/a | yes |
| host\_instance\_type | Broker instance size, such as mq.t3.micro or mq.m5.large. The t3 sizes are burstable and are for development. | `string` | `"mq.t3.micro"` | no |
| deployment\_mode | SINGLE\_INSTANCE for one node. CLUSTER\_MULTI\_AZ is RabbitMQ's three-node cluster; ACTIVE\_STANDBY\_MULTI\_AZ is ActiveMQ's pair. | `string` | `"SINGLE_INSTANCE"` | no |
| subnet\_ids | Subnets the broker sits in. One for a single instance, two in different zones for either multi-AZ mode. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups controlling who may connect. | `list(string)` | `[]` | no |
| users | Broker users keyed by username. RabbitMQ takes exactly one, and manages the rest through its own management interface. | <pre>map(object({<br/>    password         = string<br/>    console_access   = optional(bool, false)<br/>    groups           = optional(list(string), [])<br/>    replication_user = optional(bool, false)<br/>  }))</pre> | n/a | yes |
| publicly\_accessible | Give the broker a public endpoint. Off, because a message broker on the internet is one credential away from being someone else's. | `bool` | `false` | no |
| kms\_key\_arn | KMS key for encryption at rest. ActiveMQ only; RabbitMQ always uses the AWS-owned key. Null uses the AWS-owned key, which is still encryption, just not a key you control. | `string` | `null` | no |
| storage\_type | ebs or efs. RabbitMQ is ebs only. ActiveMQ defaults to efs, which is durable across zones and slower. | `string` | `null` | no |
| general\_log\_enabled | Publish the general broker log to CloudWatch Logs. | `bool` | `true` | no |
| audit\_log\_enabled | Publish the audit log to CloudWatch Logs. ActiveMQ only; RabbitMQ has no audit log. | `bool` | `false` | no |
| configuration | Broker configuration to create and apply. ActiveMQ takes XML, RabbitMQ takes Cuttlefish. Null leaves the engine defaults in place. | <pre>object({<br/>    data        = string<br/>    description = optional(string)<br/>  })</pre> | `null` | no |
| maintenance\_window | Weekly window AWS may restart the broker in. Null lets AWS choose one, which is a restart at a time nobody picked. | <pre>object({<br/>    day_of_week = string<br/>    time_of_day = string<br/>    time_zone   = optional(string, "UTC")<br/>  })</pre> | `null` | no |
| auto\_minor\_version\_upgrade | Take minor engine upgrades in the maintenance window. On, because AWS deprecates old minors and an unpatched broker eventually stops being supported. | `bool` | `true` | no |
| apply\_immediately | Apply changes now rather than in the next maintenance window. A change that restarts the broker drops every connection. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Identifier of the broker. |
| arn | ARN of the broker. |
| instances | Every broker instance, each with its console URL, endpoints and IP address. |
| endpoints | Wire protocol endpoints across every instance. RabbitMQ publishes one amqps endpoint; ActiveMQ publishes five, one per protocol. |
| primary\_endpoint | First endpoint on the first instance, which is what a single-endpoint client configuration takes. |
| console\_url | Management console of the first instance. |
| configuration\_id | Identifier of the configuration this module created, or null when the engine defaults are in use. |
<!-- END_TF_DOCS -->
