# secrets-manager-secret

A secret, optionally with a first value that can be kept out of Terraform state, and optionally rotated.

## Usage

```hcl
module "api_key" {
  source = "github.com/kingletas/terraform-aws-modules//modules/secrets-manager-secret?ref=v0.6.0"

  name        = "prod/api/signing-key"
  description = "Signing key for outbound webhooks"
  kms_key_arn = module.kms.arn

  generate_password = true
  password_length   = 48
}
```

## Keeping the value out of the state file

`initial_version` and `generate_password` both put the secret into Terraform state in clear text, because Terraform records what it created.

**`secret_string_wo` does not.** It is a write-only argument: Terraform sends it to AWS and keeps no copy in state or in a plan. It needs Terraform 1.11 or later. Terraform cannot see a write-only value change, so `secret_string_wo_version` says when to write: set it to `1`, and raise it whenever you pass a new value.

```hcl
module "vendor_token" {
  source = "github.com/kingletas/terraform-aws-modules//modules/secrets-manager-secret?ref=v0.6.0"

  name                     = "prod/alerts/vendor-token"
  secret_string_wo         = var.vendor_token
  secret_string_wo_version = 1
}
```

Declare `var.vendor_token` with `ephemeral = true` in the calling configuration, so it stays out of state there too. A secret created with `initial_version` can switch to `secret_string_wo` in place: the version is updated, not destroyed and created again.

You can also create the secret **empty** here and write the value out of band, with the CLI or a rotation function: give the module none of the three, and it creates the container alone.

`secret_string` is in `ignore_changes`, so rotation and manual updates are never reverted by a later apply.

## Notes

- `recovery_window_in_days` defaults to 30. Zero deletes immediately with no way back, and a name cannot be reused while a deletion is pending.
- Rotation needs a Lambda that knows how to change the credential at both ends. Pointing at one that does not will lock you out of the thing the secret protects.
- Path-style names such as `prod/api/thing` group secrets and let an IAM policy grant a whole prefix.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | >= 6.50.0, < 7.0 |
| random | >= 3.6, < 4.0 |

### Providers

| Name | Version |
| ---- | ------- |
| random | >= 3.6, < 4.0 |
| aws | >= 6.50.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_rotation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation) | resource |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_password.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Secret name. A path such as prod/api/database groups related secrets. | `string` | n/a | yes |
| description | What this secret holds. Never put the value here. | `string` | `null` | no |
| kms\_key\_arn | KMS key encrypting the secret. Null uses the AWS-managed Secrets Manager key. | `string` | `null` | no |
| initial\_version | First version of the secret: set exactly one of value or json. Whatever is set here lands in Terraform state in clear text; prefer secret\_string\_wo. | <pre>object({<br/>    value = optional(string)<br/>    json  = optional(map(string))<br/>  })</pre> | `null` | no |
| secret\_string\_wo | Value written as a write-only argument, so it never reaches Terraform state or a plan. Takes effect only with secret\_string\_wo\_version, and cannot be combined with initial\_version or generate\_password. | `string` | `null` | no |
| secret\_string\_wo\_version | Version of secret\_string\_wo. Terraform cannot see a write-only value change, so raise this number to write a new one. Null writes no write-only value. | `number` | `null` | no |
| generate\_password | Generate a random password as the first version. It still reaches state, but nobody has to handle it. | `bool` | `false` | no |
| password\_length | Length of the generated password. | `number` | `32` | no |
| password\_override\_special | Special characters the generated password may use. Trim it to what the consuming system actually accepts. | `string` | `"!#$%&*()-_=+[]{}<>:?"` | no |
| recovery\_window\_in\_days | Days a deleted secret can be restored. Zero deletes immediately and cannot be undone. | `number` | `30` | no |
| rotation | Automatic rotation. Needs a rotation Lambda that knows how to change the credential at both ends. | <pre>object({<br/>    lambda_arn               = string<br/>    automatically_after_days = optional(number, 30)<br/>    duration                 = optional(string)<br/>  })</pre> | `null` | no |
| replica\_regions | Regions to replicate the secret to, keyed by region name. | <pre>map(object({<br/>    kms_key_id = optional(string)<br/>  }))</pre> | `{}` | no |
| attach\_policy | Attach policy\_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply. | `bool` | `false` | no |
| policy\_json | Resource policy on the secret, for cross-account access. | `string` | `null` | no |
| tags | Tags applied to the secret. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the secret, which is what an IAM policy and an ECS task definition reference. |
| id | ID of the secret. |
| name | Name of the secret. |
| version\_id | Version ID of the first version, or null when none was written. |
| replica\_regions | Regions the secret is replicated to. |
<!-- END_TF_DOCS -->
