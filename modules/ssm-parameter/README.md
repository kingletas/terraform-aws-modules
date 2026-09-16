# ssm-parameter

Parameters written as a set, with the shape and the values kept in separate variables.

## Usage

```hcl
module "config" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ssm-parameter?ref=v0.5.0"

  parameters = {
    "/prod/api/log-level"    = { description = "Application log level" }
    "/prod/api/webhook-key"  = { type = "SecureString", description = "Outbound webhook signature key" }
  }

  values = {
    "/prod/api/log-level"   = "info"
    "/prod/api/webhook-key" = var.webhook_key
  }

  kms_key_arn = module.kms.arn
}
```

## Why the values are a separate variable

A parameter's *name* is not a secret; its value may be. Marking one map sensitive would hide the paths too, and Terraform refuses to iterate over a sensitive value at all: `for_each` on it fails the plan.

Splitting them keeps the paths visible in a plan, where you want to see which parameters are changing, while the values stay marked sensitive.

## Notes

- `SecureString` is what makes a value encrypted. The type is per-parameter and the module does not guess.
- Advanced tier costs money per parameter per month and raises the size limit to 8 KB. Standard is free and caps at 4 KB.
- Every path in `parameters` needs an entry in `values`. The plan fails and names each path that has none.
- A parameter that already exists fails the apply unless `overwrite_existing` is set.

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
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| parameters | Parameters keyed by full path, such as /prod/api/log-level. This carries the shape; the values go in `values`. | <pre>map(object({<br/>    type            = optional(string, "String")<br/>    description     = optional(string)<br/>    tier            = optional(string, "Standard")<br/>    data_type       = optional(string, "text")<br/>    allowed_pattern = optional(string)<br/>  }))</pre> | n/a | yes |
| values | Parameter values, keyed by the same paths as `parameters`. Kept separate so the map itself can be marked sensitive without making every path a secret. | `map(string)` | n/a | yes |
| kms\_key\_arn | KMS key encrypting SecureString parameters. Null uses the AWS-managed SSM key. | `string` | `null` | no |
| overwrite\_existing | Take ownership of a parameter that already exists rather than failing. | `bool` | `false` | no |
| tags | Tags applied to every parameter. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arns | Parameter ARNs, keyed by path. |
| names | Parameter names, keyed by path. |
| versions | Current version number of each parameter, keyed by path. |
<!-- END_TF_DOCS -->
