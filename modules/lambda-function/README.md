# lambda-function

A function with a managed log group, optional X-Ray tracing, and its event sources and permissions.

## Usage

```hcl
module "processor" {
  source = "github.com/kingletas/terraform-aws-modules//modules/lambda-function?ref=v0.3.0"

  name     = "order-processor"
  role_arn = module.processor_role.arn

  s3_bucket = module.artifacts.id
  s3_key    = "order-processor/v1.4.2.zip"

  handler = "index.handler"
  runtime = "python3.13"

  memory_size = 1024
  timeout     = 60

  event_source_mappings = {
    orders = {
      event_source_arn = module.order_queue.arn
      batch_size       = 10
    }
  }
}
```

## The log group is created here on purpose

Left alone, Lambda creates its own log group on first invocation with **no expiry**, and it is not managed by Terraform. That group grows forever and nobody notices until the CloudWatch bill does.

This module creates the group first, with retention set, and points the function at it.

## Notes

- **`arn` and `invoke_arn` are different.** API Gateway and EventBridge need `invoke_arn`; an IAM policy needs `arn`. Using the wrong one gives an integration error that does not say so.
- **Always set `source_arn` on an invoke permission.** Without it, granting `apigateway.amazonaws.com` lets *any* API Gateway in *any* account invoke your function.
- More memory also buys more CPU, so a compute-bound function is often cheaper at 1024 MB than at 512, because it finishes more than twice as fast.
- `tracing_mode` defaults to `PassThrough`, which follows a trace an upstream service started. `Active` starts traces itself and needs `xray:PutTraceSegments` and `xray:PutTelemetryRecords` on the role you pass in `role_arn`; this module does not add them.
- Putting a function in a VPC means it reaches the internet only through a NAT gateway or VPC endpoints.
- `arm64` costs less per millisecond than `x86_64` and is the default here.

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
| [aws_lambda_event_source_mapping.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_provisioned_concurrency_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_provisioned_concurrency_config) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Function name, also used for the log group. | `string` | n/a | yes |
| description | What this function does. | `string` | `null` | no |
| package\_type | Zip for a code archive, Image for a container image from ECR. | `string` | `"Zip"` | no |
| filename | Local path to a deployment archive. Use this or s3\_bucket, or image\_uri for a container. | `string` | `null` | no |
| source\_code\_hash | Base64 SHA-256 of the archive. Without it Terraform cannot tell that the code changed. | `string` | `null` | no |
| s3\_bucket | Bucket holding the deployment archive. | `string` | `null` | no |
| s3\_key | Key of the deployment archive. | `string` | `null` | no |
| s3\_object\_version | Version of the archive object, so a deploy pins an exact build. | `string` | `null` | no |
| image\_uri | ECR image URI. Required when package\_type is Image. | `string` | `null` | no |
| handler | Entry point, such as index.handler. Required for a Zip package. | `string` | `null` | no |
| runtime | Runtime, such as python3.13 or nodejs22.x. Required for a Zip package. | `string` | `null` | no |
| architecture | arm64 is cheaper per millisecond than x86\_64 and is the better default unless a dependency needs otherwise. | `string` | `"arm64"` | no |
| role\_arn | Execution role. It needs permission to write to its own log group at the very least. | `string` | n/a | yes |
| memory\_size | Memory in mebibytes. CPU is allocated in proportion, so more memory often costs less overall. | `number` | `512` | no |
| timeout | Seconds before the function is killed. Behind an API Gateway, a value above 29 cannot be reached anyway. | `number` | `30` | no |
| environment\_variables | Environment variables. Anything secret belongs in Secrets Manager, read at runtime. | `map(string)` | `{}` | no |
| kms\_key\_arn | KMS key encrypting environment variables at rest and the log group. | `string` | `null` | no |
| vpc\_config | Run the function inside a VPC. It then reaches the internet only through a NAT gateway or VPC endpoints. | <pre>object({<br/>    subnet_ids         = list(string)<br/>    security_group_ids = list(string)<br/>  })</pre> | `null` | no |
| layers | Layer ARNs to attach, at most five. | `list(string)` | `[]` | no |
| reserved\_concurrent\_executions | Cap on concurrent executions, which also reserves them. Set to -1 for no cap. | `number` | `-1` | no |
| provisioned\_concurrency | Pre-warmed execution environments on the published version, removing cold starts. Billed whether used or not. Zero disables it. | `number` | `0` | no |
| publish | Publish a numbered version on each change, which is what an alias and provisioned concurrency point at. | `bool` | `false` | no |
| dead\_letter\_target\_arn | SQS queue or SNS topic receiving asynchronous invocations that exhausted their retries. | `string` | `null` | no |
| tracing\_mode | X-Ray tracing: PassThrough follows an existing trace, Active starts one. Active needs xray:PutTraceSegments and xray:PutTelemetryRecords on the execution role, which this module does not manage. | `string` | `"PassThrough"` | no |
| log\_retention\_days | Days to keep logs. Without a managed log group, Lambda creates one that never expires. | `number` | `365` | no |
| event\_source\_mappings | Pull-based event sources keyed by a stable name: SQS, Kinesis, DynamoDB streams. | <pre>map(object({<br/>    event_source_arn                   = string<br/>    batch_size                         = optional(number, 10)<br/>    maximum_batching_window_in_seconds = optional(number)<br/>    starting_position                  = optional(string)<br/>    function_response_types            = optional(list(string), [])<br/>    maximum_retry_attempts             = optional(number)<br/>    enabled                            = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| allowed\_invoke\_principals | Services allowed to invoke the function, keyed by a stable name. Always set source\_arn, or any caller of that service can invoke it. | <pre>map(object({<br/>    principal  = string<br/>    source_arn = optional(string)<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the function. |
| name | Name of the function. |
| invoke\_arn | ARN used by API Gateway and EventBridge to invoke the function, which is not the same as its ARN. |
| version | Published version, or $LATEST when publishing is off. |
| qualified\_arn | ARN including the version qualifier. |
| log\_group\_name | CloudWatch log group holding the function's logs. |
| event\_source\_mapping\_uuids | Event source mapping UUIDs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
