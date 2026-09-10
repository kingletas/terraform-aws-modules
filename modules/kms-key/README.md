# kms-key

A customer-managed key with rotation on, an alias, and a key policy built from the principals you name.

## Usage

```hcl
module "kms" {
  source = "github.com/kingletas/terraform-aws-modules//modules/kms-key?ref=v0.1.0"

  name        = "platform-data"
  description = "Encrypts application data at rest"

  user_arns          = [module.task_role.arn]
  service_principals = ["logs.us-east-1.amazonaws.com"]
}
```

## The key policy is the real access control

A KMS key's own policy is evaluated *before* IAM. With no explicit policy, AWS applies a default that grants account root full control, which effectively delegates to IAM — and that is what most keys end up with by accident.

This module always writes a policy. With no `admin_arns` it names account root, which reproduces the default behaviour deliberately rather than by omission. Naming real principals in `admin_arns` narrows it, and **a key policy that names nobody who can administer it is a key nobody can recover**.

## Notes

- A CloudWatch log group encrypted with a key needs `logs.<region>.amazonaws.com` in `service_principals`, or the log group cannot be created and the error does not mention the key.
- `deletion_window_in_days` is the only window in which a scheduled deletion can be cancelled. Seven days is short for a key protecting production data.
- Rotation applies to symmetric keys only. It rotates the backing material; the key ID and every ciphertext stay valid.

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
| [aws_kms_alias.extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Alias name, without the alias/ prefix. | `string` | n/a | yes |
| description | What this key encrypts. | `string` | n/a | yes |
| key\_usage | ENCRYPT\_DECRYPT for data, SIGN\_VERIFY for signatures, GENERATE\_VERIFY\_MAC for message authentication. | `string` | `"ENCRYPT_DECRYPT"` | no |
| customer\_master\_key\_spec | Key algorithm. SYMMETRIC\_DEFAULT is the usual choice; the RSA and ECC specs are for signing. | `string` | `"SYMMETRIC_DEFAULT"` | no |
| multi\_region | Make the key replicable to other regions. Cannot be changed later. | `bool` | `false` | no |
| enable\_key\_rotation | Rotate the backing key automatically. Only applies to symmetric keys. | `bool` | `true` | no |
| rotation\_period\_in\_days | Days between automatic rotations, between 90 and 2560. | `number` | `365` | no |
| deletion\_window\_in\_days | Days a scheduled deletion waits. This is the only window in which a deletion can be cancelled, so short is risky. | `number` | `30` | no |
| admin\_arns | Principals allowed to administer the key. Empty falls back to account root, which grants every IAM identity that has kms permissions. | `list(string)` | `[]` | no |
| user\_arns | Principals allowed to encrypt and decrypt with the key. | `list(string)` | `[]` | no |
| service\_principals | AWS service principals allowed to use the key, such as logs.us-east-1.amazonaws.com. | `list(string)` | `[]` | no |
| policy\_json | A complete key policy, replacing the one this module builds. Use it when the generated policy is not enough. | `string` | `null` | no |
| aliases | Extra aliases, without the alias/ prefix. | `list(string)` | `[]` | no |
| tags | Tags applied to the key. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the key, which is what most resources want. |
| key\_id | ID of the key. |
| alias\_name | Primary alias, including the alias/ prefix. |
| alias\_arn | ARN of the primary alias. |
<!-- END_TF_DOCS -->
