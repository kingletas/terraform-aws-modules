# api-gateway-rest

A REST API with a deployed stage, access logging, throttling and X-Ray tracing.

## Usage

```hcl
module "api" {
  source = "github.com/kingletas/terraform-aws-modules//modules/api-gateway-rest?ref=v0.6.0"

  name       = "platform-api"
  stage_name = "v1"

  routes = {
    create_order = {
      path              = "orders"
      method            = "POST"
      lambda_invoke_arn = module.create_order.invoke_arn
      authorization     = "COGNITO_USER_POOLS"
      authorizer_key    = "users"
    }
  }

  authorizers = {
    users = {
      provider_arns = [module.users.arn]
    }
  }

  throttling_rate_limit = 200

  # Set true in one stack per account and region, unless something else already sets API Gateway's CloudWatch role.
  manage_account_cloudwatch_role = true
}
```

An `openapi_body` replaces `routes` entirely and suits a large API better. The document is then the single definition of the API, and it can be generated from the same source as the client.

## Redeployment is not automatic

A REST API's stage serves a *deployment*, which is a snapshot. Changing a route without a new deployment leaves the old snapshot serving, with no error anywhere.

This module hashes `openapi_body`, `routes` and `authorizers` into the deployment's `triggers`, so a change to any of them forces a redeploy. Methods or integrations added to the API outside the module are not in that hash, and changing them does not redeploy the stage.

## Notes

- **A `PRIVATE` API allows nothing without a resource policy.** It is the one endpoint type where omitting `policy_json` leaves the API unreachable.
- Behind API Gateway the hard timeout is 29 seconds, so a Lambda timeout above that cannot be reached.
- `throttling_rate_limit = -1` removes the limit, which is a bill with no ceiling.
- **Access logging needs a CloudWatch role set on the account**, once per account and region. Without it the stage fails to create with an error about the account settings. Set `manage_account_cloudwatch_role = true` to have this module create the role and set it, or leave it off where another stack already manages that setting. Destroying the module leaves the setting in place.
- Every route must state its `authorization`: `NONE`, `AWS_IAM`, `CUSTOM` or `COGNITO_USER_POOLS`. `NONE` on a `REGIONAL` or `EDGE` endpoint is a public route.
- Every route except a `MOCK` integration needs `lambda_invoke_arn` or `integration_uri`. The module does not grant API Gateway permission to invoke a Lambda function: add an `aws_lambda_permission` whose `source_arn` is built from the `arn` output (the API's execution ARN).
- A route path can be up to six segments deep, such as `/orders/{id}/items`, and `/` attaches the method to the API root.
- A top-level API resource is keyed by its path exactly as a route writes it, `orders` or `/orders`. Changing that spelling later replaces the resource and everything under it.

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
| [aws_api_gateway_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_account) | resource |
| [aws_api_gateway_authorizer.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_authorizer) | resource |
| [aws_api_gateway_deployment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_integration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_method.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_settings.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_resource.level_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.level_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.level_3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.level_4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.level_5](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.level_6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.account_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.account_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | API name. | `string` | n/a | yes |
| description | What this API serves. | `string` | `null` | no |
| openapi\_body | OpenAPI document defining the whole API. Set this, or define routes instead. | `string` | `null` | no |
| routes | Routes keyed by a stable name. A path such as /orders/{id} may be up to six segments deep, and / is the API root. Every route states its authorization, so a public route is a choice rather than a default. Ignored when openapi\_body is set. | <pre>map(object({<br/>    path                    = string<br/>    method                  = string<br/>    authorization           = string<br/>    authorizer_key          = optional(string)<br/>    api_key_required        = optional(bool, false)<br/>    lambda_invoke_arn       = optional(string)<br/>    integration_type        = optional(string, "AWS_PROXY")<br/>    integration_uri         = optional(string)<br/>    integration_http_method = optional(string, "POST")<br/>    request_parameters      = optional(map(bool), {})<br/>  }))</pre> | `{}` | no |
| authorizers | Authorizers keyed by a stable name, referenced by a route's authorizer\_key. | <pre>map(object({<br/>    type                   = optional(string, "COGNITO_USER_POOLS")<br/>    provider_arns          = optional(list(string), [])<br/>    identity_source        = optional(string, "method.request.header.Authorization")<br/>    authorizer_uri         = optional(string)<br/>    authorizer_credentials = optional(string)<br/>    result_ttl_seconds     = optional(number, 300)<br/>  }))</pre> | `{}` | no |
| endpoint\_type | REGIONAL for most APIs, PRIVATE for one reachable only through a VPC endpoint, EDGE to front it with CloudFront. | `string` | `"REGIONAL"` | no |
| vpc\_endpoint\_ids | VPC endpoints allowed to reach a PRIVATE API. | `list(string)` | `[]` | no |
| stage\_name | Stage to deploy to, which becomes the first path segment of the invoke URL. | `string` | `"v1"` | no |
| throttling\_rate\_limit | Steady-state requests per second across the stage. Minus one leaves it unlimited, which is a bill with no ceiling. | `number` | `100` | no |
| throttling\_burst\_limit | Burst capacity above the steady rate. | `number` | `200` | no |
| log\_retention\_days | Days to keep access logs. | `number` | `365` | no |
| kms\_key\_arn | KMS key encrypting the access log group. | `string` | `null` | no |
| xray\_tracing\_enabled | Trace requests through to the integration with X-Ray. | `bool` | `true` | no |
| metrics\_enabled | Publish per-method CloudWatch metrics. Useful, and billed as custom metrics. | `bool` | `true` | no |
| policy\_json | Resource policy. Required in practice for a PRIVATE API, which otherwise allows nothing. | `string` | `null` | no |
| manage\_account\_cloudwatch\_role | Create the IAM role API Gateway uses to write logs and set it on the account. Access logging fails without that account setting, but it is one per account and region, so leave this off where something else already manages it. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the REST API. |
| arn | Execution ARN, which is what a Lambda permission's source\_arn is built from. |
| root\_resource\_id | ID of the API's root resource. |
| invoke\_url | URL the stage is served at. |
| stage\_name | Name of the deployed stage. |
| log\_group\_name | CloudWatch log group holding access logs. |
<!-- END_TF_DOCS -->
