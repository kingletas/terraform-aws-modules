# api-gateway-rest

A REST API with a deployed stage, access logging, throttling and X-Ray tracing.

## Usage

```hcl
module "api" {
  source = "github.com/kingletas/terraform-aws-modules//modules/api-gateway-rest?ref=v0.1.0"

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
}
```

An `openapi_body` replaces `routes` entirely and is the better route for a large API — the document is then the single definition, and it can be generated from the same source as the client.

## Redeployment is not automatic

A REST API's stage serves a *deployment*, which is a snapshot. Changing a route without a new deployment leaves the old snapshot serving, with no error anywhere.

This module hashes the API's shape into the deployment's `triggers`, so a route change forces a redeploy. If you add resources outside the module, add them to that hash too.

## Notes

- **A `PRIVATE` API allows nothing without a resource policy.** It is the one endpoint type where omitting `policy_json` leaves you locked out.
- Behind API Gateway the hard timeout is 29 seconds, so a Lambda timeout above that cannot be reached.
- `throttling_rate_limit = -1` removes the limit, which is a bill with no ceiling.

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
| [aws_api_gateway_authorizer.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_authorizer) | resource |
| [aws_api_gateway_deployment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_integration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_method.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_settings.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_resource.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | API name. | `string` | n/a | yes |
| description | What this API serves. | `string` | `null` | no |
| openapi\_body | OpenAPI document defining the whole API. Set this, or define routes instead. | `string` | `null` | no |
| routes | Routes keyed by a stable name. Paths use {braces} for path parameters. Ignored when openapi\_body is set. | <pre>map(object({<br/>    path                    = string<br/>    method                  = string<br/>    authorization           = optional(string, "NONE")<br/>    authorizer_key          = optional(string)<br/>    api_key_required        = optional(bool, false)<br/>    lambda_invoke_arn       = optional(string)<br/>    integration_type        = optional(string, "AWS_PROXY")<br/>    integration_uri         = optional(string)<br/>    integration_http_method = optional(string, "POST")<br/>    request_parameters      = optional(map(bool), {})<br/>  }))</pre> | `{}` | no |
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
