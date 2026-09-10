# dms-replication

A DMS replication instance, its endpoints and its tasks, with credentials read from Secrets Manager rather than written into the endpoint.

## Usage

```hcl
module "replication" {
  source = "github.com/kingletas/terraform-aws-modules//modules/dms-replication?ref=v0.1.0"

  name           = "warehouse-load"
  instance_class = "dms.t3.medium"

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.dms_sg.id]
  kms_key_arn        = module.kms.arn

  secrets_access_role_arn      = module.dms_secrets_role.arn
  secrets_manager_endpoint_dns = module.endpoints.interface_dns_names["secretsmanager"][0].dns_name

  endpoints = {
    erp = {
      endpoint_type = "source"
      engine_name   = "sqlserver"
      database_name = "erp"
      secret_arn    = module.erp_secret.arn
    }

    warehouse = {
      endpoint_type = "target"
      engine_name   = "redshift"
      database_name = "warehouse"
      secret_arn    = module.warehouse_secret.arn
    }
  }

  tasks = {
    erp = {
      source_endpoint     = "erp"
      target_endpoint     = "warehouse"
      migration_type      = "full-load-and-cdc"
      table_mappings_json = file("${path.module}/mappings/erp.json")
    }
  }
}
```

> [!danger] `secrets_manager_endpoint_dns` is what makes a private task work
> An endpoint using `secret_arn` reads its credentials **at connection time, over the public Secrets Manager address**. In a private subnet with no route to the internet that request does not fail — **it hangs**, and the connection test times out with an error that never mentions Secrets Manager.
>
> Passing this variable sets `secretsManagerEndpointOverride` on every endpoint, pointing at your VPC interface endpoint. It is the single most common reason a private DMS task never connects, and nothing in the console suggests it.

## Migration types

| Type | What it does |
|---|---|
| `full-load` | Copies what is there and stops |
| `cdc` | Streams changes only, from a point you specify |
| `full-load-and-cdc` | Copies, then keeps streaming. The usual choice for a warehouse |

Change capture reads the source's transaction log, which usually needs enabling on the source first — supplemental logging on Oracle, CDC on SQL Server, binlog with `ROW` format on MySQL. **DMS cannot turn that on for you**, and a task configured for CDC against a source without it fails at start.

## Notes

- **The instance is sized by change volume, not by source size.** A 2 TB database with a few thousand changes an hour needs a small instance; a 50 GB one under heavy write load needs a large one.
- `multi_az = false` by default. A single-AZ instance failing mid-load means restarting the task, which for a full load can be hours.
- `replication_task_settings` is in `ignore_changes`, because a running task's settings drift as DMS records its own progress.
- **Prefer `secret_arn` over inline `username` and `password`**, which land in Terraform state in clear text.
- `private_ip_addresses` is what a source system's firewall team will ask you for.

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
| [aws_dms_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_endpoint) | resource |
| [aws_dms_replication_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_instance) | resource |
| [aws_dms_replication_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_subnet_group) | resource |
| [aws_dms_replication_task.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_task) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the replication instance, its endpoints and its tasks. | `string` | n/a | yes |
| instance\_class | Replication instance class. Sizing follows source change volume, not source size. | `string` | `"dms.t3.medium"` | no |
| engine\_version | DMS engine version. Null takes the current default, which moves under you. | `string` | `null` | no |
| allocated\_storage | Storage in gibibytes for the instance's own working files and logs. | `number` | `50` | no |
| subnet\_ids | Subnets for the replication subnet group. Private subnets in at least two availability zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups on the replication instance. It needs outbound to both source and target. | `list(string)` | `[]` | no |
| multi\_az | Run a standby in another zone. A single-AZ instance failing mid-load means restarting the task. | `bool` | `false` | no |
| publicly\_accessible | Give the instance a public address, for a source outside your VPC with no VPN. | `bool` | `false` | no |
| kms\_key\_arn | KMS key encrypting the instance storage and the endpoints. Null uses the AWS-managed DMS key. | `string` | `null` | no |
| secrets\_manager\_endpoint\_dns | DNS name of the Secrets Manager VPC interface endpoint.<br/><br/>A DMS endpoint in a private subnet reads its credentials over the public<br/>Secrets Manager address unless it is told otherwise, and with no route it<br/>simply hangs. Passing this sets secretsManagerEndpointOverride on every<br/>endpoint, which is the single most common reason a private DMS task never<br/>connects. | `string` | `null` | no |
| secrets\_access\_role\_arn | Role DMS assumes to read endpoint credentials from Secrets Manager. Required when any endpoint uses a secret. | `string` | `null` | no |
| endpoints | Source and target endpoints keyed by a stable name. Prefer secret\_arn over an inline username and password, which land in Terraform state. | <pre>map(object({<br/>    endpoint_type = string<br/>    engine_name   = string<br/><br/>    secret_arn  = optional(string)<br/>    server_name = optional(string)<br/>    port        = optional(number)<br/>    username    = optional(string)<br/>    password    = optional(string)<br/><br/>    database_name               = optional(string)<br/>    ssl_mode                    = optional(string, "require")<br/>    extra_connection_attributes = optional(string)<br/>  }))</pre> | n/a | yes |
| tasks | Replication tasks keyed by a stable name. migration\_type is full-load, cdc, or full-load-and-cdc. | <pre>map(object({<br/>    source_endpoint     = string<br/>    target_endpoint     = string<br/>    migration_type      = optional(string, "full-load-and-cdc")<br/>    table_mappings_json = string<br/>    task_settings_json  = optional(string)<br/>    start_on_create     = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| replication\_instance\_arn | ARN of the replication instance. |
| replication\_instance\_id | Identifier of the replication instance. |
| private\_ip\_addresses | Addresses the instance connects from. This is what a source system's firewall allow-lists. |
| public\_ip\_addresses | Public addresses, empty unless the instance is publicly accessible. |
| endpoint\_arns | Endpoint ARNs, keyed by the name you gave each one. |
| task\_arns | Replication task ARNs, keyed by the name you gave each one. |
| subnet\_group\_id | ID of the replication subnet group. |
<!-- END_TF_DOCS -->
