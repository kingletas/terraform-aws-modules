# ssm-parameter

Parameters written as a set, with the shape and the values kept in separate variables.

## Usage

```hcl
module "config" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ssm-parameter?ref=v0.7.0"

  path_prefix = format("/%s/api", var.environment)

  parameters = {
    "log-level"   = { description = "Application log level" }
    "webhook-key" = { type = "SecureString", description = "Outbound webhook signature key" }
  }

  values = {
    "log-level"   = "info"
    "webhook-key" = var.webhook_key
  }

  kms_key_arn = module.kms.arn
}
```

With `var.environment` set to `staging`, that writes `/staging/api/log-level` and `/staging/api/webhook-key`. The full path is built inside the module, and the `names` output is what reads it back:

```hcl
WEBHOOK_KEY_PARAMETER = module.config.names["webhook-key"]
```

## Why the keys are short names and not paths

The key of a `for_each` becomes part of the resource address, and a `moved` block may only name an address with a constant key. A map keyed by the full path put the environment inside that key, so one configuration serving staging and production had no single literal to write:

```hcl
# Rejected: "A single static variable reference is required."
moved {
  from = aws_ssm_parameter.log_level
  to   = module.config.aws_ssm_parameter.this["/${var.environment}/api/log-level"]
}
```

Keying on the short name takes the computed part out of the address, so an existing parameter can be adopted into the module instead of being destroyed and recreated:

```hcl
moved {
  from = aws_ssm_parameter.log_level
  to   = module.config.aws_ssm_parameter.this["log-level"]
}
```

A name may still contain slashes (`reports/webhook-key`), which is what lets one call cover a whole subtree. Keep it a literal you write rather than a value you compute, or the address goes back to being one no `moved` block can name.

## Why the values are a separate variable

A parameter's *name* is not a secret; its value may be. Marking one map sensitive would hide the names too, and Terraform refuses to iterate over a sensitive value at all: `for_each` on it fails the plan.

Splitting them keeps the names visible in a plan, where you want to see which parameters are changing, while the values stay marked sensitive.

## Notes

- `SecureString` is what makes a value encrypted. The type is per-parameter and the module does not guess.
- Advanced tier costs money per parameter per month and raises the size limit to 8 KB. Standard is free and caps at 4 KB.
- Every name in `parameters` needs an entry in `values`. The plan fails and names each one that has none.
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
| path\_prefix | Path every parameter hangs under, such as /prod/api. Empty puts them at the root of the hierarchy. | `string` | `""` | no |
| parameters | Parameters keyed by a short name under `path_prefix`, such as log-level or api/webhook-key. The key is the address a `moved` block names, so keep it a literal you write rather than a value you compute. This carries the shape; the values go in `values`. | <pre>map(object({<br/>    type            = optional(string, "String")<br/>    description     = optional(string)<br/>    tier            = optional(string, "Standard")<br/>    data_type       = optional(string, "text")<br/>    allowed_pattern = optional(string)<br/>  }))</pre> | n/a | yes |
| values | Parameter values, keyed by the same names as `parameters`. Kept separate so the map itself can be marked sensitive without making every name a secret. | `map(string)` | n/a | yes |
| kms\_key\_arn | KMS key encrypting SecureString parameters. Null uses the AWS-managed SSM key. | `string` | `null` | no |
| overwrite\_existing | Take ownership of a parameter that already exists rather than failing. | `bool` | `false` | no |
| tags | Tags applied to every parameter. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arns | Parameter ARNs, keyed by the name the caller gave. |
| names | Full parameter paths, keyed by the name the caller gave. This is what an application reads a parameter by. |
| versions | Current version number of each parameter, keyed by the name the caller gave. |
<!-- END_TF_DOCS -->
