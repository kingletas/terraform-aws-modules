# secrets-manager-secret

A secret, optionally with a generated first value, and optionally rotated.

## Usage

```hcl
module "api_key" {
  source = "github.com/kingletas/terraform-aws-modules//modules/secrets-manager-secret?ref=v0.3.0"

  name        = "prod/api/signing-key"
  description = "Signing key for outbound webhooks"
  kms_key_arn = module.kms.arn

  generate_password = true
  password_length   = 48
}
```

## Everything Terraform writes reaches the state file

`initial_version` and `generate_password` both put the secret into Terraform state in clear text. That is unavoidable, because Terraform records what it created.

The genuinely safe pattern is to create the secret **empty** here and write the value out of band, with the CLI or a rotation function. The module supports that: give it neither an initial value nor `generate_password`, and it creates the container alone.

`secret_string` is in `ignore_changes`, so rotation and manual updates are never reverted by a later apply.

## Notes

- `recovery_window_in_days` defaults to 30. Zero deletes immediately with no way back, and a name cannot be reused while a deletion is pending.
- Rotation needs a Lambda that knows how to change the credential at both ends. Pointing at one that does not will lock you out of the thing the secret protects.
- Path-style names such as `prod/api/thing` group secrets and let an IAM policy grant a whole prefix.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |
| random | >= 3.6, < 4.0 |

### Providers

| Name | Version |
| ---- | ------- |
| random | >= 3.6, < 4.0 |
| aws | >= 6.0, < 7.0 |

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
| initial\_version | First version of the secret: set exactly one of value or json. Whatever is set here lands in Terraform state in clear text; prefer generate\_password or writing the value out of band. | <pre>object({<br/>    value = optional(string)<br/>    json  = optional(map(string))<br/>  })</pre> | `null` | no |
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
