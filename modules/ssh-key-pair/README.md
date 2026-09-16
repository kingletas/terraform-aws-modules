# ssh-key-pair

An EC2 key pair, from a public key you supply or a fresh pair it generates.

## Usage

Registering an existing key, which is the better path:

```hcl
module "ssh_key" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ssh-key-pair?ref=v0.3.1"

  name       = "storefront-production"
  public_key = file("~/.ssh/id_ed25519.pub")
}
```

Generating one, where nobody has a key to hand:

```hcl
module "ssh_key" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ssh-key-pair?ref=v0.3.1"

  name        = "storefront-staging"
  kms_key_arn = module.kms.arn

  store_in_secrets_manager = true
}
```

> [!WARNING]
> **A generated private key is in Terraform state, in clear text**
>
> That is unavoidable, because Terraform records what it created, and it is why supplying a public key is preferred for anything long-lived. Whoever can read the state file can read the key.
>
> `write_private_key_to` additionally puts it on the disk of whoever ran the apply, at mode 0600. It is off by default. `store_in_secrets_manager` is on instead, so a CI job or a second operator can fetch it without it being emailed around.

## Notes

- **ED25519 by default.** Smaller and faster than RSA, and supported everywhere that matters now. Older tooling that cannot read it needs `algorithm = "RSA"`.
- `recovery_window_in_days` defaults to 7. A secret pending deletion holds its name, so a short window matters when you are recreating a stack repeatedly.
- `was_generated` is exported so a caller can branch on it: for instance, only wiring the secret ARN into an IAM policy when there is one.
- Prefer Systems Manager Session Manager over SSH entirely where you can. This module exists for the cases where you cannot: a bastion, a database tunnel, or an AMI without the agent.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |
| local | >= 2.4, < 3.0 |
| tls | >= 4.0, < 5.0 |

### Providers

| Name | Version |
| ---- | ------- |
| tls | >= 4.0, < 5.0 |
| aws | >= 6.0, < 7.0 |
| local | >= 2.4, < 3.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_key_pair.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [local_sensitive_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Key pair name in EC2. | `string` | n/a | yes |
| public\_key | An existing public key to register. Leave null to generate a new pair, which puts the private key in Terraform state. | `string` | `null` | no |
| algorithm | Algorithm for a generated key. ED25519 is smaller and faster; RSA is what older tooling still expects. | `string` | `"ED25519"` | no |
| rsa\_bits | Key size for RSA. Ignored for ED25519. | `number` | `4096` | no |
| write\_private\_key\_to | Path to write a generated private key to, at mode 0600. Null writes nothing.<br/><br/>Writing it makes the key usable immediately and puts a credential on the<br/>disk of whoever ran the apply. Prefer null, and read the key out of the<br/>secret below. | `string` | `null` | no |
| store\_in\_secrets\_manager | Also store a generated private key in Secrets Manager, which is where a CI job or another operator can reach it. | `bool` | `true` | no |
| kms\_key\_arn | KMS key encrypting the secret. Null uses the AWS-managed Secrets Manager key. | `string` | `null` | no |
| recovery\_window\_in\_days | Days a deleted secret can be restored. Zero deletes immediately, which frees the name for reuse. | `number` | `7` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| key\_name | Name of the EC2 key pair, which a launch template or instance takes. |
| key\_pair\_id | ID of the EC2 key pair. |
| fingerprint | Fingerprint of the public key. |
| public\_key\_openssh | The public key in OpenSSH format, whether generated or supplied. |
| private\_key\_openssh | The generated private key, or null when an existing public key was supplied. |
| secret\_arn | Secrets Manager secret holding the generated private key, or null when it is not stored. |
| was\_generated | Whether the module generated the key rather than registering one you supplied. |
<!-- END_TF_DOCS -->
