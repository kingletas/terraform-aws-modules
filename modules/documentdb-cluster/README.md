# documentdb-cluster

A MongoDB-compatible cluster, encrypted, with TLS and audit logging on by default.

## Usage

```hcl
module "documents" {
  source = "github.com/kingletas/terraform-aws-modules//modules/documentdb-cluster?ref=v0.3.0"

  name           = "platform-docs"
  instance_count = 2
  instance_class = "db.r6g.large"

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.docdb_sg.id]
}
```

## Notes

- **DocumentDB is MongoDB-compatible, not MongoDB.** Compatibility is by API version, and drivers sometimes use commands it does not implement. Check the supported operations before porting an application.
- `parameters` defaults to `tls = enabled` and `audit_logs = enabled`, so clients need the Amazon RDS certificate bundle. Setting `parameters` replaces that whole map, so include both keys in your own map to keep them. Turning TLS off is a parameter change and a cluster reboot.
- The first instance is the writer. Reads go to `reader_endpoint`.

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
| [aws_docdb_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster) | resource |
| [aws_docdb_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster_instance) | resource |
| [aws_docdb_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_cluster_parameter_group) | resource |
| [aws_docdb_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/docdb_subnet_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Cluster identifier and the prefix for everything around it. | `string` | n/a | yes |
| engine\_version | DocumentDB engine version. | `string` | `"5.0.0"` | no |
| instance\_count | Cluster instances. The first is the writer; the rest are readers. | `number` | `2` | no |
| instance\_class | Instance class, such as db.t4g.medium. | `string` | `"db.t4g.medium"` | no |
| username | Master username. | `string` | `"dbadmin"` | no |
| manage\_master\_password | Let DocumentDB generate and rotate the master password in Secrets Manager, so it never reaches Terraform state. | `bool` | `true` | no |
| password | Master password. Only used when manage\_master\_password is false, and it lands in state in clear text. | `string` | `null` | no |
| subnet\_ids | Subnets for the DB subnet group. Private subnets in at least two availability zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups controlling who may connect. | `list(string)` | `[]` | no |
| port | Port to listen on. | `number` | `27017` | no |
| parameters | Cluster parameters. A parameter group is created only when this is non-empty. TLS is enabled here by default. | `map(string)` | <pre>{<br/>  "audit_logs": "enabled",<br/>  "tls": "enabled"<br/>}</pre> | no |
| parameter\_group\_family | Parameter group family, such as docdb5.0. | `string` | `"docdb5.0"` | no |
| backup\_retention\_period | Days of automated backups. | `number` | `14` | no |
| preferred\_backup\_window | Daily backup window in UTC. | `string` | `"03:00-04:00"` | no |
| preferred\_maintenance\_window | Weekly maintenance window in UTC. | `string` | `"sun:04:00-sun:05:00"` | no |
| kms\_key\_arn | KMS key for storage encryption. Null uses the AWS-managed key. | `string` | `null` | no |
| enabled\_cloudwatch\_logs\_exports | Log types shipped to CloudWatch: audit and profiler. | `list(string)` | <pre>[<br/>  "audit"<br/>]</pre> | no |
| deletion\_protection | Refuse to delete the cluster until this is turned off. | `bool` | `true` | no |
| skip\_final\_snapshot | Delete without taking a final snapshot. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| cluster\_identifier | Identifier of the cluster. |
| arn | ARN of the cluster. |
| endpoint | Writer endpoint. |
| reader\_endpoint | Reader endpoint, load balanced across replicas. |
| port | Port the cluster listens on. |
| master\_user\_secret\_arn | Secrets Manager secret holding the master password, or null when the password is managed by hand. |
| instance\_endpoints | Per-instance endpoints, in creation order. |
<!-- END_TF_DOCS -->
