# account-defaults

Account and region-wide settings that apply above whatever an individual resource asks for.

Apply it once per account and region, not once per stack.

## Usage

```hcl
module "account_defaults" {
  source = "github.com/kingletas/terraform-aws-modules//modules/account-defaults?ref=v0.7.0"

  ebs_encryption_by_default = true
  block_s3_public_access    = true

  default_security_group_vpc_ids = {
    platform = module.vpc.vpc_id
  }
}
```

## Why these four

Each closes a gap that a per-resource setting cannot:

- **EBS encryption by default** covers a volume created in the console, by a hand-written autoscaling group, or by any Terraform that did not ask for encryption. It is regional and it does not touch existing volumes.
- **The S3 account public access block** sits above every bucket's own block. While it is on, no bucket policy can make a bucket public.
- **The IAM password policy** applies to console users, which are the accounts most often left unchecked.
- **The default security group** of a VPC permits all traffic between its members and cannot be deleted. Adopting it and giving it no rules is the only way to make it harmless. This matters most for a VPC created outside this library, whose default group is otherwise still open.

## Password expiry is off by default

`max_age_days` defaults to 0, meaning no expiry. Forced rotation leads people to pick weaker passwords, and NIST guidance does not recommend it. Length and a second factor do the work instead, which is why the minimum length here is 14 rather than 8.

Set `max_age_days` if a compliance regime requires expiry.

## Notes

- **These settings are account-wide.** Applying this module from two stacks in the same account gives two Terraform states that both manage the same settings, and each apply undoes the other. Apply it once, from a baseline stack.
- `ebs_encryption_by_default = false` does not simply stop managing the setting: it explicitly turns encryption by default off for the region.
- `password_policy = null` leaves the account's own password policy untouched.
- The default security group is **adopted**, not created. Terraform takes over a resource that already exists, and removing this module from the configuration leaves the group empty rather than restoring its original rules.

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
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ebs_default_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_default_kms_key) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_iam_account_password_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| ebs\_encryption\_by\_default | Encrypt every new EBS volume in this region, whatever the resource that creates it asked for. It does not touch existing volumes. | `bool` | `true` | no |
| ebs\_default\_kms\_key | Key used when a volume is encrypted by default and names none. An object rather than a bare ARN, so a key created in the same plan can be passed in. Null uses the AWS-managed EBS key. | <pre>object({<br/>    arn = string<br/>  })</pre> | `null` | no |
| block\_s3\_public\_access | Block public access to every bucket in the account, above whatever each bucket's own settings say. | `bool` | `true` | no |
| password\_policy | IAM password policy for console users, with no expiry by default, or null to leave the account's own policy untouched. | <pre>object({<br/>    minimum_length        = optional(number, 14)<br/>    require_lowercase     = optional(bool, true)<br/>    require_uppercase     = optional(bool, true)<br/>    require_numbers       = optional(bool, true)<br/>    require_symbols       = optional(bool, true)<br/>    allow_users_to_change = optional(bool, true)<br/>    max_age_days          = optional(number, 0)<br/>    reuse_prevention      = optional(number, 24)<br/>    hard_expiry           = optional(bool, false)<br/>  })</pre> | `{}` | no |
| default\_security\_group\_vpc\_ids | VPCs whose default security group should be emptied, keyed by a stable name. A VPC created outside this library keeps its permissive default otherwise. | `map(string)` | `{}` | no |
| region\_name | Region these settings apply to, for the output only. EBS encryption and the public access block are regional and account-wide respectively. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| account\_id | Account these settings apply to. |
| region | Region the regional settings apply to. |
| ebs\_encryption\_by\_default | Whether new EBS volumes in this region are encrypted regardless of what asked for them. |
| s3\_public\_access\_blocked | Whether public access is blocked account-wide. |
| locked\_default\_security\_group\_ids | Default security groups emptied by this module, keyed by the name given to each VPC. |
<!-- END_TF_DOCS -->
