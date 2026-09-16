# redshift-cluster

A Redshift cluster with encryption, enhanced VPC routing and audit logging, sized by node type and count.

## Usage

```hcl
module "warehouse" {
  source = "github.com/kingletas/terraform-aws-modules//modules/redshift-cluster?ref=v0.3.0"

  name            = "analytics"
  database_name   = "warehouse"
  node_type       = "ra3.large"
  number_of_nodes = 2

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.warehouse_sg.id]
  kms_key_arn        = module.kms.arn

  iam_role_arns        = [module.redshift_role.arn]
  default_iam_role_arn = module.redshift_role.arn
  logging              = { bucket = module.audit_logs.id }
}
```

## Enhanced VPC routing is on, and it matters

Without it, `COPY` and `UNLOAD` traffic leaves over the **public** network. Neither your security groups nor your S3 gateway endpoint apply to it, and the data transfer is billed as internet egress rather than through the endpoint.

Turning it on requires that the cluster can actually reach S3 from inside the VPC, through a gateway endpoint or a NAT gateway. Without one, `COPY` stops working entirely.

## ra3 against dc2

`ra3` separates compute from storage: you size nodes for query performance and storage grows on its own, billed separately. `dc2` has fixed local storage, so running out of disk means adding nodes you do not need for compute.

New clusters should be `ra3`. `dc2.large` still appears in older configurations and is cheaper at very small scale.

## Notes

- **A single-node cluster is a different shape.** `number_of_nodes = 1` sets `cluster_type = "single-node"` and omits the node count, which the module handles. A single node has no replication and no failover.
- `manage_master_password` is on, so Redshift generates and rotates the password in Secrets Manager and nothing readable reaches Terraform state.
- **`require_ssl` is on, in a parameter group the module always creates.** It has its own variable and cannot be set in `parameters`; the plan fails if it is. An empty `parameters` still gets this group rather than the AWS default group, where `require_ssl` is off. Clients that do not negotiate TLS cannot connect. Set `require_ssl = false` only for a client that cannot use TLS.
- The final snapshot is named `<name>-final`, with no timestamp, and the name is set even while `skip_final_snapshot` is on, so turning the skip off later needs no other change. A second destroy under the same name fails while that snapshot exists: delete or rename it first.
- Audit logging writes with an ACL, so the logging bucket needs `BucketOwnerPreferred`. It cannot be a bucket with ACLs disabled.
- `default_iam_role_arn` must also appear in `iam_role_arns`. The module checks this at plan time.

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
| [aws_redshift_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshift_cluster) | resource |
| [aws_redshift_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshift_logging) | resource |
| [aws_redshift_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshift_parameter_group) | resource |
| [aws_redshift_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshift_subnet_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Cluster identifier and the prefix for everything around it. | `string` | n/a | yes |
| database\_name | Name of the first database created in the cluster. | `string` | `"warehouse"` | no |
| node\_type | Node type. The ra3 family separates compute from storage and is what new clusters should use; dc2 is the older fixed-storage family. | `string` | `"ra3.large"` | no |
| number\_of\_nodes | Nodes in the cluster. One means a single-node cluster with no replication. | `number` | `2` | no |
| username | Master username. Cannot be a Redshift reserved word. | `string` | `"warehouse_admin"` | no |
| manage\_master\_password | Let Redshift generate and rotate the master password in Secrets Manager, so it never reaches Terraform state. | `bool` | `true` | no |
| password | Master password. Only used when manage\_master\_password is false, and it lands in state in clear text. | `string` | `null` | no |
| subnet\_ids | Subnets for the cluster subnet group. Private subnets in at least two availability zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups controlling who may connect. | `list(string)` | `[]` | no |
| port | Port to listen on. | `number` | `5439` | no |
| kms\_key\_arn | KMS key for encryption at rest. Null uses the AWS-managed Redshift key. | `string` | `null` | no |
| iam\_role\_arns | Roles the cluster may assume, for COPY from S3 and for DMS to load into it. | `list(string)` | `[]` | no |
| default\_iam\_role\_arn | Role used when a COPY or UNLOAD names none. Must also appear in iam\_role\_arns. | `string` | `null` | no |
| require\_ssl | Refuse client connections that do not use TLS. On, and set in the cluster's own parameter group whatever else parameters holds. | `bool` | `true` | no |
| parameters | Cluster parameters, added to the parameter group this module always creates. Set require\_ssl through its own variable, not here. | `map(string)` | <pre>{<br/>  "enable_user_activity_logging": "true"<br/>}</pre> | no |
| parameter\_group\_family | Parameter group family. | `string` | `"redshift-1.0"` | no |
| logging | Where connection, user and user-activity logs go. The bucket's policy must already allow the Redshift service, and it needs ACLs enabled. Null disables logging. | <pre>object({<br/>    bucket = string<br/>    prefix = optional(string)<br/>  })</pre> | `null` | no |
| automated\_snapshot\_retention\_period | Days of automated snapshots. Zero disables them. | `number` | `7` | no |
| manual\_snapshot\_retention\_period | Days a manual snapshot is kept. Minus one keeps it forever. | `number` | `90` | no |
| maintenance\_window | Weekly maintenance window in UTC. | `string` | `"sun:05:00-sun:06:00"` | no |
| allow\_version\_upgrade | Take major version upgrades during the maintenance window. | `bool` | `true` | no |
| enhanced\_vpc\_routing | Force COPY and UNLOAD traffic through the VPC, where security groups and endpoints apply to it. Without this it leaves over the public network. | `bool` | `true` | no |
| publicly\_accessible | Give the cluster a public address. Almost never right. | `bool` | `false` | no |
| skip\_final\_snapshot | Delete without a final snapshot. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Identifier of the cluster. |
| arn | ARN of the cluster. |
| endpoint | Host and port to connect to. |
| dns\_name | Hostname of the cluster, without the port. |
| port | Port the cluster listens on. |
| database\_name | Name of the first database. |
| master\_username | Master username. |
| master\_password\_secret\_arn | Secrets Manager secret holding the master password, or null when the password is managed by hand. |
| subnet\_group\_name | Name of the cluster subnet group. |
<!-- END_TF_DOCS -->
