# s3-bucket

A private S3 bucket: every public access route blocked, encrypted, versioned, and refusing plain HTTP.

## Usage

```hcl
module "assets" {
  source = "github.com/kingletas/terraform-aws-modules//modules/s3-bucket?ref=v0.3.1"

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

## Adding your own bucket policy statements

A bucket has exactly one policy, and this module writes it. Pass grants of your own, such as CloudFront or CloudTrail access, in `policy_documents`. Each entry is a policy document in JSON, and the module merges them into its policy. Do not write a second `aws_s3_bucket_policy` for the same bucket: the two would overwrite each other.

The Sid `DenyInsecureTransport` is the module's own statement, so do not use it in your documents.

The `id` and `arn` outputs wait until the bucket policy and the public access block exist. A `policy_documents` entry that refers to `module.<name>.arn` or `module.<name>.id` of the same module therefore forms a dependency cycle. Build the bucket ARN from the name you passed instead:

```hcl
locals {
  logs_bucket = "example-cloudtrail-logs"
}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${local.logs_bucket}"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "CloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${local.logs_bucket}/AWSLogs/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

module "cloudtrail_logs" {
  source = "github.com/kingletas/terraform-aws-modules//modules/s3-bucket?ref=v0.3.1"

  name             = local.logs_bucket
  policy_documents = [data.aws_iam_policy_document.cloudtrail.json]
}
```

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
| policy\_documents | IAM policy documents in JSON, merged into the bucket policy this module writes. A bucket has one policy, so grants such as CloudFront or CloudTrail access go here rather than in a second aws\_s3\_bucket\_policy. The Sid DenyInsecureTransport is reserved. Build this bucket's ARN from its name here, because the arn output waits for the policy and referencing it forms a cycle. | `list(string)` | `[]` | no |
| force\_destroy | Let terraform destroy delete a bucket that still holds objects. Off, so a destroy fails loudly rather than deleting data. | `bool` | `false` | no |
| object\_ownership | Object ownership. BucketOwnerEnforced disables ACLs entirely and is what you want unless something legacy needs them. | `string` | `"BucketOwnerEnforced"` | no |
| tags | Tags applied to the bucket. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Name of the bucket, available once the bucket policy and public access block are in place. |
| arn | ARN of the bucket, available once the bucket policy and public access block are in place. |
| domain\_name | Global domain name of the bucket. |
| regional\_domain\_name | Regional domain name, which is what CloudFront and cross-region callers should use. |
| hosted\_zone\_id | Route 53 hosted zone ID for the bucket's region, for an alias record. |
<!-- END_TF_DOCS -->
