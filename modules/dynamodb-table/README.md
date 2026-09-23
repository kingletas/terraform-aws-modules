# dynamodb-table

A table with point-in-time recovery and deletion protection on, and indexes declared as maps.

## Usage

```hcl
module "sessions" {
  source = "github.com/kingletas/terraform-aws-modules//modules/dynamodb-table?ref=v0.7.0"

  name      = "sessions"
  hash_key  = "session_id"
  range_key = "created_at"

  attributes = [
    { name = "session_id", type = "S" },
    { name = "created_at", type = "N" },
    { name = "user_id", type = "S" },
  ]

  global_secondary_indexes = {
    by_user = {
      hash_key = "user_id"
    }
  }

  ttl_attribute = "expires_at"
}
```

## What `attributes` is for

Only attributes used as a key somewhere (the table's keys, or any index's keys) are declared. DynamoDB has no schema for anything else, so listing a non-key attribute is an error rather than documentation.

## Notes

- **The module needs AWS provider 6.37.0 or later**, because it declares global secondary index keys with the `key_schema` block.
- **Changing `hash_key` or `range_key` replaces the table**, which destroys the data. Decide the key design before the first apply.
- A local secondary index can only be created with the table. A global one can be added later.
- `ttl_attribute` names an attribute holding an expiry as epoch seconds. Deletion happens within a couple of days of that time, not at it.
- Each global secondary index is billed as its own table.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.37.0, < 7.0 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.37.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Table name. | `string` | n/a | yes |
| billing\_mode | PAY\_PER\_REQUEST bills per read and write and needs no capacity planning. PROVISIONED is cheaper at steady high volume. | `string` | `"PAY_PER_REQUEST"` | no |
| hash\_key | Partition key attribute name. Cannot be changed without replacing the table. | `string` | n/a | yes |
| range\_key | Sort key attribute name. Cannot be changed without replacing the table. | `string` | `null` | no |
| attributes | Attributes used as a key anywhere, including in an index. Type is S, N or B. Attributes that are not keys are not declared here. | <pre>list(object({<br/>    name = string<br/>    type = string<br/>  }))</pre> | n/a | yes |
| read\_capacity | Provisioned read units. Ignored unless billing\_mode is PROVISIONED. | `number` | `null` | no |
| write\_capacity | Provisioned write units. Ignored unless billing\_mode is PROVISIONED. | `number` | `null` | no |
| global\_secondary\_indexes | Global secondary indexes keyed by index name. Each is billed as its own table. | <pre>map(object({<br/>    hash_key           = string<br/>    range_key          = optional(string)<br/>    projection_type    = optional(string, "ALL")<br/>    non_key_attributes = optional(list(string))<br/>    read_capacity      = optional(number)<br/>    write_capacity     = optional(number)<br/>  }))</pre> | `{}` | no |
| local\_secondary\_indexes | Local secondary indexes keyed by index name. These can only be created with the table. | <pre>map(object({<br/>    range_key          = string<br/>    projection_type    = optional(string, "ALL")<br/>    non_key_attributes = optional(list(string))<br/>  }))</pre> | `{}` | no |
| ttl\_attribute | Attribute holding an expiry timestamp in epoch seconds. Null disables time to live. | `string` | `null` | no |
| stream\_view\_type | What a change event carries: KEYS\_ONLY, NEW\_IMAGE, OLD\_IMAGE or NEW\_AND\_OLD\_IMAGES. Null disables the stream. | `string` | `null` | no |
| point\_in\_time\_recovery | Keep 35 days of continuous backups, restorable to any second. | `bool` | `true` | no |
| deletion\_protection | Refuse to delete the table until this is turned off. | `bool` | `true` | no |
| kms\_key\_arn | Customer-managed KMS key. Null uses the AWS-owned key, which is still encryption at rest. | `string` | `null` | no |
| tags | Tags applied to the table. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| name | Name of the table. |
| arn | ARN of the table. |
| id | ID of the table, which is the same as its name. |
| stream\_arn | ARN of the change stream, or null when no stream is enabled. |
| stream\_label | Timestamp identifying the current stream, or null when no stream is enabled. |
<!-- END_TF_DOCS -->
