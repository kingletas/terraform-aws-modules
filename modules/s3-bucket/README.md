# s3-bucket

A private S3 bucket: every public access route blocked, encrypted, versioned, and refusing plain HTTP.

## Usage

```hcl
module "assets" {
  source = "github.com/kingletas/terraform-aws-modules//modules/s3-bucket?ref=v0.1.0"

  name        = "example-assets-prod"
  kms_key_arn = module.kms.arn

  lifecycle_rules = {
    expire_old_versions = {
      noncurrent_version_expiration_days = 90
    }
  }

  tags = { Environment = "production" }
}
```

## What is fixed rather than configurable

- **Public access is blocked four ways.** While that block stands, a bucket policy cannot re-open the bucket by accident.
- **A bucket policy denies anything arriving over plain HTTP.** Encryption at rest without encryption in flight is half the job.
- **Unfinished multipart uploads expire.** They are billed as storage and do not appear in the console, so they accumulate silently.

## Notes

- `force_destroy` is off, so `terraform destroy` fails on a bucket that still holds objects rather than deleting the data.
- `object_ownership` defaults to `BucketOwnerEnforced`, which turns ACLs off entirely. CloudFront access logging needs ACLs, so a log bucket must use `BucketOwnerPreferred`.
- Bucket names are global across all of AWS, not per account or per region.

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
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Bucket name. Must be globally unique across all of AWS. | `string` | n/a | yes |
| versioning\_enabled | Keep every version of an object. The only defence against an overwrite or a delete. | `bool` | `true` | no |
| kms\_key\_arn | KMS key for server-side encryption. Null uses SSE-S3, which is free and still encryption at rest. | `string` | `null` | no |
| bucket\_key\_enabled | Use an S3 bucket key to cut KMS request costs on a busy bucket. Ignored without kms\_key\_arn. | `bool` | `true` | no |
| lifecycle\_rules | Lifecycle rules keyed by a stable name. Each moves or expires objects on an age in days. | <pre>map(object({<br/>    enabled                                = optional(bool, true)<br/>    prefix                                 = optional(string)<br/>    transition_days                        = optional(number)<br/>    transition_storage_class               = optional(string, "STANDARD_IA")<br/>    expiration_days                        = optional(number)<br/>    noncurrent_version_expiration_days     = optional(number)<br/>    abort_incomplete_multipart_upload_days = optional(number, 7)<br/>  }))</pre> | `{}` | no |
| abort\_incomplete\_multipart\_upload\_days | Days before an unfinished multipart upload is discarded. These are billed as storage and are invisible in the console. | `number` | `7` | no |
| logging | Where to write server access logs. Null disables access logging. | <pre>object({<br/>    target_bucket = string<br/>    target_prefix = optional(string, "s3-access-logs/")<br/>  })</pre> | `null` | no |
| force\_destroy | Let terraform destroy delete a bucket that still holds objects. Off, so a destroy fails loudly rather than deleting data. | `bool` | `false` | no |
| object\_ownership | Object ownership. BucketOwnerEnforced disables ACLs entirely and is what you want unless something legacy needs them. | `string` | `"BucketOwnerEnforced"` | no |
| tags | Tags applied to the bucket. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Name of the bucket. |
| arn | ARN of the bucket. |
| domain\_name | Global domain name of the bucket. |
| regional\_domain\_name | Regional domain name, which is what CloudFront and cross-region callers should use. |
| hosted\_zone\_id | Route 53 hosted zone ID for the bucket's region, for an alias record. |
<!-- END_TF_DOCS -->
