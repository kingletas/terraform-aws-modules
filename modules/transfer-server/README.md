# transfer-server

A managed SFTP server over an S3 bucket, with each user confined to its own prefix.

## Usage

```hcl
module "sftp" {
  source = "github.com/kingletas/terraform-aws-modules//modules/transfer-server?ref=v0.5.0"

  name        = "platform-sftp"
  bucket_name = module.exchange.id

  users = {
    partner-acme = {
      public_keys = { primary = file("keys/acme.pub") }
    }
    partner-readonly = {
      public_keys = { primary = file("keys/readonly.pub") }
      read_only   = true
    }
  }
}
```

## Each user sees only its own directory

Every user gets its own IAM role and a logical home directory. It maps to `s3://<bucket>/<username>`, or to `s3://<bucket>/<home_directory>` when the user sets `home_directory`. The user's policy allows access only under that prefix, so a partner cannot list the bucket root or read another partner's files. Because the home directory is logical, they cannot navigate above it either.

## Notes

- **Public keys only.** Service-managed identity has no password authentication, which is the right answer for a partner integration.
- **Name each public key.** `public_keys` is keyed by a name you choose, and each key is addressed as `username/key_name`. Adding a second key under a new name leaves the first one in place, which is how a rotation is done: add the new key, have the partner switch, then remove the old entry. Renaming a key replaces it.
- **Plain `FTP` is unencrypted** and should never be in `protocols` on a public endpoint. `FTPS` needs a certificate.
- `address_allocation_ids` gives the server fixed Elastic IPs, which is what a partner's firewall team will ask for. It needs `endpoint_type = "VPC"`.
- `home_directory` must name a prefix below the bucket root and cannot contain `..`. The plan fails otherwise.
- A bucket encrypted with a customer-managed key needs `bucket_kms_key = { arn = ... }`, or every read and write is denied. Each user is granted `kms:Decrypt`, plus `kms:GenerateDataKey` unless `read_only` is set, and only through S3. The key policy must also allow the account to delegate key use to IAM.
- The server is billed hourly from creation, whether anyone connects or not, plus per gigabyte transferred.

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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_transfer_server.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_server) | resource |
| [aws_transfer_ssh_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_ssh_key) | resource |
| [aws_transfer_user.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_user) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the server and the resources around it. | `string` | n/a | yes |
| protocols | Protocols served: SFTP, FTPS or FTP. Plain FTP is unencrypted and should never face the internet. | `list(string)` | <pre>[<br/>  "SFTP"<br/>]</pre> | no |
| endpoint\_type | PUBLIC is reachable from the internet. VPC places it in your subnets, where a security group can restrict it. | `string` | `"PUBLIC"` | no |
| vpc\_id | VPC for a VPC endpoint type. | `string` | `null` | no |
| subnet\_ids | Subnets for a VPC endpoint type. | `list(string)` | `[]` | no |
| security\_group\_ids | Security groups for a VPC endpoint type. | `list(string)` | `[]` | no |
| address\_allocation\_ids | Elastic IP allocations, which give the server fixed addresses a partner can allow-list. | `list(string)` | `[]` | no |
| certificate\_arn | ACM certificate. Required when FTPS is in the protocol list. | `string` | `null` | no |
| security\_policy\_name | Cryptographic policy governing which ciphers and key exchanges are offered. | `string` | `"TransferSecurityPolicy-2025-03"` | no |
| bucket\_name | S3 bucket users are given access to. | `string` | n/a | yes |
| users | Users keyed by username. Each user's public\_keys are keyed by a name you choose, such as "2026-rotation", which becomes part of the key's resource address. Each user is confined to its home directory in the bucket, which defaults to a prefix named after the user, and cannot see anything above it. | <pre>map(object({<br/>    public_keys    = map(string)<br/>    home_directory = optional(string)<br/>    read_only      = optional(bool, false)<br/>    posix_uid      = optional(number)<br/>    posix_gid      = optional(number)<br/>  }))</pre> | `{}` | no |
| log\_retention\_days | Days to keep transfer logs. These are the record of who moved which file. | `number` | `365` | no |
| kms\_key\_arn | KMS key encrypting the log group. | `string` | `null` | no |
| bucket\_kms\_key | Customer-managed KMS key encrypting the bucket. Users are granted kms:Decrypt, and kms:GenerateDataKey when they can write, through S3 only. Null for a bucket using S3-managed keys. | <pre>object({<br/>    arn = string<br/>  })</pre> | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the transfer server. |
| arn | ARN of the transfer server. |
| endpoint | Host name partners connect to. |
| host\_key\_fingerprint | Fingerprint of the server host key. Give it to partners so they can verify what they are connecting to. |
| user\_role\_arns | Per-user IAM role ARNs, keyed by username. |
| log\_group\_name | CloudWatch log group holding transfer records. |
<!-- END_TF_DOCS -->
