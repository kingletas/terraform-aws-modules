# context

One place that decides names, tags and every environment-dependent default, so no other module has to ask which environment it is in.

This module creates nothing. It is a calculation, and that is the point — every stack that uses it agrees on what a production database looks like without repeating the decision.

## Usage

```hcl
module "context" {
  source = "github.com/kingletas/terraform-aws-modules//modules/context?ref=v0.1.0"

  project     = "storefront"
  environment = "production"
  owner       = "webops"
  cost_centre = "ecommerce"
}

module "database" {
  source = "../../modules/aurora-cluster"

  name                    = module.context.prefix
  backup_retention_period = module.context.defaults.backup_retention_days
  deletion_protection     = module.context.defaults.deletion_protection
  skip_final_snapshot     = module.context.defaults.skip_final_snapshot
  tags                    = module.context.tags
}
```

## What `defaults` decides

The reference implementations this replaces carried `var.instance_types[var.environment]` in every stack, and each stack made its own decision about retention, multi-AZ and deletion protection. Here it is one table:

| | dev | staging | uat | production |
|---|---|---|---|---|
| `multi_az` | no | no | no | **yes** |
| `deletion_protection` | no | no | yes | **yes** |
| `skip_final_snapshot` | yes | yes | no | **no** |
| `backup_retention_days` | 1 | 7 | 14 | **30** |
| `log_retention_days` | 30 | 90 | 90 | **365** |
| `single_nat_gateway` | yes | yes | yes | **no** |
| `min` / `desired` / `max` capacity | 1 / 1 / 2 | 1 / 2 / 4 | 2 / 2 / 4 | **2 / 3 / 12** |

A stack reads these rather than writing another conditional. Where a stack genuinely differs, it overrides that one value and the difference is visible in the diff.

## Three name shapes, because AWS is not consistent

- **`prefix`** — `project-environment-component`. What most resources take.
- **`short_prefix`** — the same truncated to 24 characters, for a load balancer or an OpenSearch domain where AWS caps the name and a module appends a suffix.
- **`compact_prefix`** — hyphens removed, for a CloudWatch metric namespace and anything else that rejects them.

Working these out separately in each stack is how two resources for the same thing end up with names that do not match.

## Notes

- **Production gets `Backup = true` automatically.** A tag-selected backup plan then covers production and nothing else, with no environment logic in the plan.
- `is_production` exists so callers stop comparing the environment string themselves. One place to change if a fifth environment appears.
- `name` is a small map of common suffixes — `name["alb"]`, `name["bastion"]` — for the resources every stack has.
- The environment list is validated. A typo becomes a plan error rather than a stack named `storefront-produciton`.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project | What this infrastructure is for, such as storefront or warehouse. | `string` | n/a | yes |
| environment | Which environment this is. The value decides sizing defaults and whether production guards apply. | `string` | n/a | yes |
| owner | Team answerable for this infrastructure. Appears on every resource and is what a cost report groups by. | `string` | n/a | yes |
| component | Optional component within the project, such as web or data. Becomes part of the name. | `string` | `null` | no |
| extra\_tags | Tags merged on top of the generated ones. A key that collides wins. | `map(string)` | `{}` | no |
| cost\_centre | Cost centre or budget code, for chargeback. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| prefix | Name prefix, as project-environment-component. Most resources take this. |
| short\_prefix | The prefix truncated to 24 characters, for names AWS caps at 32 with a suffix. |
| compact\_prefix | The prefix with hyphens removed, for names that reject them such as a CloudWatch metric namespace. |
| tags | Tags every resource in this project should carry. Production also gets Backup = true, which is what a tag-selected backup plan picks up. |
| is\_production | Whether production guards apply. Use it rather than comparing the environment string again. |
| defaults | Environment-appropriate defaults: multi\_az, deletion\_protection, skip\_final\_snapshot, backup\_retention\_days, log\_retention\_days, single\_nat\_gateway, min\_capacity, desired\_capacity and max\_capacity. |
| name | Function-style helper: a map from suffix to full name for a handful of common suffixes. |
<!-- END_TF_DOCS -->
