# aurora-cluster

An Aurora cluster with a writer and readers, defaulting to Serverless v2 capacity.

## Usage

```hcl
module "database" {
  source = "github.com/kingletas/terraform-aws-modules//modules/aurora-cluster?ref=v0.5.0"

  name           = "platform"
  engine         = "aurora-postgresql"
  engine_version = "16.4"

  database_name = "platform"
  subnet_ids    = values(module.vpc.private_subnet_ids)

  instances = {
    writer = { promotion_tier = 0 }
    reader = { promotion_tier = 1 }
  }

  serverless_capacity = {
    min_capacity = 0.5
    max_capacity = 16
  }
}
```

## Send reads to the reader endpoint

`endpoint` is the writer. `reader_endpoint` load balances across every reader. An application that sends reads to the writer gets correct answers and no benefit from its readers. Nothing errors; you pay for readers that do no work.

## Notes

- **Serverless v2 is `engine_mode = "provisioned"` with instance class `db.serverless`.** The old `serverless` engine mode is v1, which is a different product.
- `promotion_tier` decides who is promoted on failover. Lower wins.
- Aurora storage grows automatically and is billed for what is used. There is no `allocated_storage` to set.
- Enhanced monitoring is on every 60 seconds, through an IAM role the module creates for RDS. Set `monitoring_interval = 0` to turn it off, and no role is created.
- `skip_final_snapshot` is off, so a destroy leaves a snapshot to restore from. It is named `<name>-final`, with no timestamp, and the name is set even while the skip is on, so turning the skip off later needs no other change. A second destroy under the same name fails while that snapshot exists: delete or rename it first.

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
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_rds_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Cluster identifier and the prefix for everything around it. | `string` | n/a | yes |
| engine | aurora-postgresql or aurora-mysql. | `string` | `"aurora-postgresql"` | no |
| engine\_version | Engine version. Leave null to take whatever is current, which moves under you. | `string` | `null` | no |
| engine\_mode | provisioned covers both fixed instances and Serverless v2. The old serverless mode is v1 and is not what you want. | `string` | `"provisioned"` | no |
| instances | Cluster instances keyed by a stable name. The writer is whichever is promoted; the rest are readers. | <pre>map(object({<br/>    instance_class      = optional(string, "db.serverless")<br/>    promotion_tier      = optional(number, 1)<br/>    availability_zone   = optional(string)<br/>    publicly_accessible = optional(bool, false)<br/>  }))</pre> | <pre>{<br/>  "writer": {}<br/>}</pre> | no |
| serverless\_capacity | Serverless v2 capacity range in ACUs. Only used when an instance class is db.serverless. | <pre>object({<br/>    min_capacity = optional(number, 0.5)<br/>    max_capacity = optional(number, 4)<br/>  })</pre> | `{}` | no |
| database\_name | Name of the database created on first boot. | `string` | `null` | no |
| username | Master username. | `string` | `"dbadmin"` | no |
| manage\_master\_password | Let RDS generate and rotate the master password in Secrets Manager, so it never reaches Terraform state. | `bool` | `true` | no |
| password | Master password. Only used when manage\_master\_password is false, and it lands in state in clear text. | `string` | `null` | no |
| subnet\_ids | Subnets for the DB subnet group. Private subnets in at least two availability zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups controlling who may connect. | `list(string)` | `[]` | no |
| port | Port to listen on. Null uses the engine default. | `number` | `null` | no |
| backup\_retention\_period | Days of automated backups. | `number` | `14` | no |
| preferred\_backup\_window | Daily backup window in UTC, as hh:mm-hh:mm. | `string` | `"03:00-04:00"` | no |
| preferred\_maintenance\_window | Weekly maintenance window in UTC. | `string` | `"sun:04:00-sun:05:00"` | no |
| kms\_key\_arn | KMS key for storage encryption. Null uses the AWS-managed RDS key. | `string` | `null` | no |
| cluster\_parameters | Cluster-level engine parameters. A parameter group is created only when this is non-empty. | `map(string)` | `{}` | no |
| parameter\_group\_family | Parameter group family, such as aurora-postgresql16. Required when cluster\_parameters is non-empty. | `string` | `null` | no |
| enabled\_cloudwatch\_logs\_exports | Log types shipped to CloudWatch. | `list(string)` | `[]` | no |
| performance\_insights\_enabled | Turn on Performance Insights on every instance. | `bool` | `true` | no |
| monitoring\_interval | Enhanced monitoring interval in seconds for every instance. Zero disables it and creates no monitoring role. | `number` | `60` | no |
| iam\_database\_authentication\_enabled | Allow connecting with an IAM token instead of a stored password. | `bool` | `true` | no |
| deletion\_protection | Refuse to delete the cluster until this is turned off. | `bool` | `true` | no |
| skip\_final\_snapshot | Delete without taking a final snapshot. | `bool` | `false` | no |
| apply\_immediately | Apply changes now rather than in the next maintenance window. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| cluster\_identifier | Identifier of the cluster. |
| arn | ARN of the cluster. |
| endpoint | Writer endpoint. Send everything that writes here. |
| reader\_endpoint | Reader endpoint, load balanced across every reader instance. |
| port | Port the cluster listens on. |
| database\_name | Name of the database created on first boot. |
| master\_user\_secret\_arn | Secrets Manager secret holding the master password, or null when the password is managed by hand. |
| instance\_endpoints | Per-instance endpoints, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
