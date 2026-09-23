# opensearch-domain

A search domain inside your VPC, encrypted at rest and in flight, with HTTPS enforced.

## Usage

```hcl
module "search" {
  source = "github.com/kingletas/terraform-aws-modules//modules/opensearch-domain?ref=v0.6.0"

  name           = "platform-search"
  instance_type  = "r7g.large.search"
  instance_count = 2

  subnet_ids         = slice(values(module.vpc.private_subnet_ids), 0, 2)
  security_group_ids = [module.search_sg.id]

  master_user_arn = module.search_role.arn
}
```

## Node counts and zones

`instance_count` must divide evenly by `zone_awareness_count`, or shards spread unevenly and one zone does more work than the others. The module checks this at plan time.

Dedicated master nodes keep cluster management off the data nodes. Use **three**, never two: a two-node master quorum cannot break a tie, which is worse than one.

## Notes

- Set `subnet_ids` to place the domain in your VPC, or set `public = true` and leave `subnet_ids` empty for a public endpoint. The plan refuses both and neither. Almost nothing should be public.
- Auto-Tune is left out on T2 and T3 instance types, which do not support it, whatever `auto_tune_enabled` says.
- A domain name is capped at 28 characters.
- Fine-grained access control needs either `master_user_arn` for IAM, or `master_user` for an internal database. Prefer IAM.
- Changing most cluster settings triggers a blue/green deployment that takes tens of minutes and does not interrupt queries.

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
| [aws_opensearch_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearch_domain) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Domain name. AWS caps this at 28 characters. | `string` | n/a | yes |
| engine\_version | Engine version, such as OpenSearch\_2.17 or Elasticsearch\_7.10. | `string` | `"OpenSearch_2.17"` | no |
| instance\_type | Data node instance type. | `string` | `"t3.small.search"` | no |
| instance\_count | Number of data nodes. Use a multiple of your availability zone count so shards spread evenly. | `number` | `2` | no |
| dedicated\_master | Dedicated master nodes, which keep cluster management off the data nodes. Use three, never two. | <pre>object({<br/>    enabled        = optional(bool, false)<br/>    instance_type  = optional(string, "t3.small.search")<br/>    instance_count = optional(number, 3)<br/>  })</pre> | `{}` | no |
| zone\_awareness\_count | Availability zones to spread across. One disables zone awareness. | `number` | `2` | no |
| volume\_size | EBS volume size per data node, in gibibytes. | `number` | `20` | no |
| volume\_type | EBS volume type for data nodes. | `string` | `"gp3"` | no |
| subnet\_ids | Private subnets to place the domain in. Required unless public is true. | `list(string)` | `[]` | no |
| public | Put the domain on a public endpoint instead of in subnets. Almost never right, so it has to be asked for. | `bool` | `false` | no |
| security\_group\_ids | Security groups for the domain's network interfaces. | `list(string)` | `[]` | no |
| kms\_key\_arn | KMS key for encryption at rest. Null uses the AWS-managed OpenSearch key. | `string` | `null` | no |
| master\_user | Internal database master user, used when fine-grained access control is on. Prefer master\_user\_arn and IAM. | <pre>object({<br/>    name     = string<br/>    password = string<br/>  })</pre> | `null` | no |
| master\_user\_arn | IAM ARN acting as master user under fine-grained access control. Cannot be combined with master\_user. | `string` | `null` | no |
| access\_policy\_json | Domain access policy. Null leaves access to whatever fine-grained access control and the security groups allow. | `string` | `null` | no |
| log\_publishing | Log publishing keyed by log type: INDEX\_SLOW\_LOGS, SEARCH\_SLOW\_LOGS, ES\_APPLICATION\_LOGS or AUDIT\_LOGS. | <pre>map(object({<br/>    cloudwatch_log_group_arn = string<br/>    enabled                  = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| auto\_tune\_enabled | Let AWS adjust JVM and queue settings from observed load. Always off on T2 and T3 instance types, which do not support it. | `bool` | `true` | no |
| off\_peak\_window\_start\_hour | Hour in UTC when the daily maintenance window opens. | `number` | `3` | no |
| tags | Tags applied to the domain. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the domain. |
| arn | ARN of the domain. |
| endpoint | Endpoint to send search and index requests to. |
| dashboard\_endpoint | Endpoint of the OpenSearch Dashboards interface. |
| domain\_name | Name of the domain. |
<!-- END_TF_DOCS -->
