# rds-instance

A single managed relational database, with the master password held by AWS rather than by Terraform.

## Usage

```hcl
module "database" {
  source = "github.com/kingletas/terraform-aws-modules//modules/rds-instance?ref=v0.7.0"

  name           = "platform-prod"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.m7g.large"

  database_name = "platform"
  subnet_ids    = values(module.vpc.private_subnet_ids)

  security_group_ids = [module.database_sg.id]
  kms_key_arn        = module.kms.arn
}
```

## The password never passes through Terraform

`manage_master_password` is on by default. RDS generates the password, stores it in Secrets Manager and rotates it, and the module outputs the secret ARN. Nothing readable ever reaches Terraform state.

Setting `manage_master_password = false` and supplying `password` puts a credential in state in clear text, where anyone who can read the state file can read it. Do that only when something downstream genuinely cannot read a secret.

## Notes

- `multi_az` doubles the instance cost and is what makes a zone failure survivable. It does not give you a read replica: the standby serves nothing.
- `skip_final_snapshot` is off, so a destroy leaves a snapshot to restore from. It is named `<name>-final`, with no timestamp, and the name is set even while the skip is on, so turning the skip off later needs no other change. A second destroy under the same name fails while that snapshot exists: delete or rename it first.
- ARNs are built for the current partition, so the module works in GovCloud and China regions as well as the commercial one.
- Supplying `parameters` needs `parameter_group_family` as well, such as `postgres16`.
- Storage autoscaling raises `allocated_storage` up to `max_allocated_storage`. It never lowers it, and storage cannot be reduced without a rebuild.

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
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Identifier for the instance and the resources around it. | `string` | n/a | yes |
| engine | Database engine: mysql, postgres, mariadb, oracle-se2, sqlserver-ex and so on. | `string` | `"postgres"` | no |
| engine\_version | Engine version. Leave null to take the latest the family offers, which moves under you. | `string` | `null` | no |
| instance\_class | Instance class, such as db.t4g.medium. | `string` | `"db.t4g.medium"` | no |
| allocated\_storage | Storage in gibibytes. | `number` | `50` | no |
| max\_allocated\_storage | Ceiling for storage autoscaling. Set to 0 to keep storage fixed. | `number` | `500` | no |
| storage\_type | gp3 for general use, io1 or io2 where you need guaranteed IOPS. | `string` | `"gp3"` | no |
| database\_name | Name of the database created on first boot. | `string` | `null` | no |
| username | Master username. Cannot be a reserved word for the engine. | `string` | `"dbadmin"` | no |
| manage\_master\_password | Let RDS generate and rotate the master password in Secrets Manager, so it never passes through Terraform state. | `bool` | `true` | no |
| password | Master password. Only used when manage\_master\_password is false, and it lands in state in clear text. | `string` | `null` | no |
| subnet\_ids | Subnets for the DB subnet group. Use private subnets in at least two availability zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups controlling who may connect. | `list(string)` | `[]` | no |
| port | Port to listen on. Null uses the engine default. | `number` | `null` | no |
| multi\_az | Keep a synchronous standby in another availability zone. Doubles the instance cost and is what makes a failover survivable. | `bool` | `true` | no |
| backup\_retention\_period | Days of automated backups. Zero disables them and with them point-in-time recovery. | `number` | `14` | no |
| backup\_window | Daily backup window in UTC, as hh:mm-hh:mm. | `string` | `"03:00-04:00"` | no |
| maintenance\_window | Weekly maintenance window in UTC, as ddd:hh:mm-ddd:hh:mm. | `string` | `"sun:04:00-sun:05:00"` | no |
| kms\_key\_arn | KMS key for storage encryption. Null uses the AWS-managed RDS key. | `string` | `null` | no |
| performance\_insights\_enabled | Turn on Performance Insights. Free for seven days of history. | `bool` | `true` | no |
| monitoring\_interval | Enhanced monitoring interval in seconds. Zero disables it. | `number` | `60` | no |
| enabled\_cloudwatch\_logs\_exports | Log types shipped to CloudWatch. Postgres takes postgresql and upgrade; MySQL takes error, general, slowquery and audit. | `list(string)` | `[]` | no |
| parameters | Engine parameters, as a map of name to value. A parameter group is created only when this is non-empty. | `map(string)` | `{}` | no |
| parameter\_group\_family | Parameter group family, such as postgres16. Required when parameters is non-empty. | `string` | `null` | no |
| iam\_database\_authentication\_enabled | Allow connecting with an IAM token instead of a stored password. Not every engine and class supports it. | `bool` | `true` | no |
| deletion\_protection | Refuse to delete the instance until this is turned off. | `bool` | `true` | no |
| skip\_final\_snapshot | Delete without taking a final snapshot. Off, so a destroy leaves something to restore from. | `bool` | `false` | no |
| delete\_automated\_backups | Delete the automated backups when the instance is deleted. Off, so they stay restorable for their retention period after a destroy. | `bool` | `false` | no |
| apply\_immediately | Apply changes now rather than in the next maintenance window. Some changes cause an outage. | `bool` | `false` | no |
| auto\_minor\_version\_upgrade | Take minor engine upgrades automatically during the maintenance window. | `bool` | `true` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Identifier of the instance. |
| arn | ARN of the instance. |
| endpoint | Host and port to connect to. |
| address | Hostname of the instance, without the port. |
| port | Port the instance listens on. |
| database\_name | Name of the database created on first boot. |
| master\_user\_secret\_arn | Secrets Manager secret holding the master password, or null when the password is managed by hand. |
| subnet\_group\_name | Name of the DB subnet group. |
<!-- END_TF_DOCS -->
