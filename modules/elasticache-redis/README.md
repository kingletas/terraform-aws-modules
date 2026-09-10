# elasticache-redis

A Valkey or Redis replication group, encrypted in flight and at rest, with failover on.

## Usage

```hcl
module "cache" {
  source = "github.com/kingletas/terraform-aws-modules//modules/elasticache-redis?ref=v0.1.0"

  name       = "platform-cache"
  node_type  = "cache.r7g.large"
  subnet_ids = values(module.vpc.private_subnet_ids)

  security_group_ids      = [module.cache_sg.id]
  replicas_per_node_group = 2
}
```

## Transit encryption is a client change

`transit_encryption_enabled` defaults to on, which is right, and it means **every client must connect with TLS**. A client library configured for a plain connection fails after this module applies, and the error usually looks like a protocol fault rather than a TLS one. Change the clients first, or turn it off deliberately.

## Notes

- **Cluster mode is implied by `num_node_groups` above 1**, and it changes which endpoint you use: `configuration_endpoint_address` rather than `primary_endpoint_address`. Client libraries need to be told they are talking to a cluster.
- Automatic failover needs at least one replica. With `replicas_per_node_group = 0` the module turns it off rather than failing.
- `engine` defaults to `valkey`, which is the fork most of the ecosystem moved to and is cheaper per node than Redis.

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
| [aws_elasticache_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group) | resource |
| [aws_elasticache_replication_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Replication group identifier and the prefix for everything around it. | `string` | n/a | yes |
| engine | redis or valkey. Valkey is the fork most of the ecosystem moved to and is cheaper per node. | `string` | `"valkey"` | no |
| engine\_version | Engine version. Leave null to take the current default. | `string` | `null` | no |
| node\_type | Node type, such as cache.t4g.micro. | `string` | `"cache.t4g.micro"` | no |
| num\_node\_groups | Number of shards. More than one turns on cluster mode, which most client libraries need to be told about. | `number` | `1` | no |
| replicas\_per\_node\_group | Read replicas per shard. At least one is needed for automatic failover. | `number` | `1` | no |
| subnet\_ids | Subnets for the cache subnet group. Private subnets in at least two availability zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups controlling who may connect. | `list(string)` | `[]` | no |
| port | Port to listen on. | `number` | `6379` | no |
| parameters | Engine parameters. A parameter group is created only when this is non-empty. | `map(string)` | `{}` | no |
| parameter\_group\_family | Parameter group family, such as valkey8. Required when parameters is non-empty. | `string` | `null` | no |
| automatic\_failover\_enabled | Promote a replica when the primary fails. Needs at least one replica. | `bool` | `true` | no |
| multi\_az\_enabled | Place replicas in other availability zones. Needs automatic failover. | `bool` | `true` | no |
| at\_rest\_encryption\_enabled | Encrypt data on disk. | `bool` | `true` | no |
| transit\_encryption\_enabled | Encrypt data in flight. Clients must then connect with TLS, which is a client change as well as a server one. | `bool` | `true` | no |
| auth\_token | Password required on connect. Needs transit encryption, and must be 16 to 128 printable characters. | `string` | `null` | no |
| kms\_key\_arn | KMS key for encryption at rest. Null uses the AWS-managed key. | `string` | `null` | no |
| snapshot\_retention\_limit | Days of automatic snapshots. Zero disables them. | `number` | `5` | no |
| snapshot\_window | Daily snapshot window in UTC, as hh:mm-hh:mm. | `string` | `"03:00-04:00"` | no |
| maintenance\_window | Weekly maintenance window in UTC. | `string` | `"sun:04:00-sun:05:00"` | no |
| auto\_minor\_version\_upgrade | Take minor engine upgrades automatically. | `bool` | `true` | no |
| apply\_immediately | Apply changes now rather than in the next maintenance window. | `bool` | `false` | no |
| log\_delivery | Log delivery keyed by log type, either slow-log or engine-log. | <pre>map(object({<br/>    destination      = string<br/>    destination_type = optional(string, "cloudwatch-logs")<br/>    log_format       = optional(string, "json")<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Identifier of the replication group. |
| arn | ARN of the replication group. |
| primary\_endpoint\_address | Write endpoint. Null in cluster mode, where the configuration endpoint is used instead. |
| reader\_endpoint\_address | Read endpoint, load balanced across replicas. Null in cluster mode. |
| configuration\_endpoint\_address | Cluster-mode configuration endpoint, which a cluster-aware client discovers shards through. |
| port | Port the cache listens on. |
| member\_clusters | Cache cluster IDs making up this replication group. |
<!-- END_TF_DOCS -->
