# kinesis-firehose

A delivery stream that buffers records and writes them somewhere, either an S3 bucket or an HTTP endpoint such as an observability vendor.

## Usage

```hcl
module "metrics_to_vendor" {
  source = "github.com/kingletas/terraform-aws-modules//modules/kinesis-firehose?ref=v0.3.1"

  name     = "metrics"
  role_arn = module.firehose_role.arn

  http_endpoint_destination = {
    url               = "https://aws-kinesis-http-intake.example.com/v1/input"
    name              = "metrics-vendor"
    access_key        = var.vendor_api_key
    backup_bucket_arn = module.backup_bucket.arn
    common_attributes = { environment = "production" }
  }

  log_group_name = module.firehose_logs.name
}
```

## An HTTP destination always has a bucket behind it

`s3_configuration` is not optional on an HTTP endpoint, whatever the backup mode. That is the design, not a quirk: when the endpoint is down or rejects a batch, the records go to S3 instead of being lost.

| `backup_mode` | What lands in the bucket |
|---|---|
| `FailedDataOnly`, the default | Only what the endpoint refused. This is the copy you go looking for during an incident |
| `AllData` | Every record, whether or not the endpoint took it |

`retry_duration` is how long Firehose keeps trying before giving up and writing to the backup. Five minutes by default. Longer means fewer records in the bucket and a longer gap at the endpoint; shorter means the reverse.

## Without a log group, a failing delivery is silent

`log_group_name` defaults to null, which turns CloudWatch logging off, and that is the one default here worth overriding every time. Firehose does not fail loudly. A stream whose destination is refusing every batch looks exactly like a stream with nothing to deliver, and the delivery errors that explain why are only ever written to the log group.

Create one with [`cloudwatch-log-group`](../cloudwatch-log-group) and pass its name. The default is null only because this module cannot invent a log group, not because off is a reasonable place to leave it.

## Buffering is the latency and cost dial

Firehose delivers when either the size or the time threshold is reached, whichever comes first.

- **S3** defaults to 64 MB or 300 seconds, which suits archival and produces large, cheap objects.
- **HTTP** defaults to 4 MB or 60 seconds, because a vendor endpoint wants data while it is still current.

Smaller buffers mean more requests, more objects and more cost. Larger ones mean a stream that is quiet for longer between deliveries, which matters when someone is watching a dashboard during an incident.

## Notes

- **The role is yours to build.** Firehose assumes it to write to the destination and to the backup bucket, and the two are often different buckets. [`iam-role`](../iam-role) with `firehose.amazonaws.com` trusted.
- **Server-side encryption is on** with the AWS-owned key unless `kms_key_arn` is set. It protects records inside the stream, not what is written at the far end, which is the destination bucket's own encryption.
- `access_key` is the vendor's API key. It is sensitive, and it is in Terraform state. Keep it in Secrets Manager and pass the value in.
- **A plaintext endpoint is refused at plan**, because Firehose would otherwise put that access key on the wire in the clear.

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
| [aws_kinesis_firehose_delivery_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Delivery stream name, unique within the account and region. | `string` | n/a | yes |
| role\_arn | Role Firehose assumes to write to the destination and to its backup bucket. Build it with the iam-role module. | `string` | n/a | yes |
| s3\_destination | Deliver to S3. Set exactly one of this and http\_endpoint\_destination. | <pre>object({<br/>    bucket_arn          = string<br/>    prefix              = optional(string)<br/>    error_output_prefix = optional(string)<br/>    buffering_size      = optional(number, 64)<br/>    buffering_interval  = optional(number, 300)<br/>    compression_format  = optional(string, "GZIP")<br/>    kms_key_arn         = optional(string)<br/>  })</pre> | `null` | no |
| http\_endpoint\_destination | Deliver to an HTTP endpoint such as Datadog or New Relic, with an S3 bucket behind it. Set exactly one of this and s3\_destination. | <pre>object({<br/>    url                 = string<br/>    name                = string<br/>    access_key          = optional(string)<br/>    buffering_size      = optional(number, 4)<br/>    buffering_interval  = optional(number, 60)<br/>    content_encoding    = optional(string, "GZIP")<br/>    retry_duration      = optional(number, 300)<br/>    common_attributes   = optional(map(string), {})<br/>    backup_mode         = optional(string, "FailedDataOnly")<br/>    backup_bucket_arn   = string<br/>    backup_prefix       = optional(string)<br/>    backup_error_prefix = optional(string)<br/>  })</pre> | `null` | no |
| kms\_key\_arn | KMS key encrypting records at rest inside the stream. Null uses the AWS-owned key. | `string` | `null` | no |
| log\_group\_name | CloudWatch log group Firehose writes delivery errors to. Null turns logging off, and a failing delivery then says nothing anywhere. | `string` | `null` | no |
| log\_stream\_name | Log stream within that group. | `string` | `"delivery"` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the delivery stream. This is the firehose\_arn a metric stream or a log subscription writes to. |
| name | Name of the delivery stream. |
| destination | Destination type the stream was built for, either extended\_s3 or http\_endpoint. |
<!-- END_TF_DOCS -->
