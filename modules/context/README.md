# context

One place that decides names, tags and every environment-dependent default, so no other module has to ask which environment it is in.

This module creates no resources. It only computes values, so every stack that uses it agrees on what a production database looks like without repeating the decision.

## Usage

```hcl
module "context" {
  source = "github.com/kingletas/terraform-aws-modules//modules/context?ref=v0.6.0"

  project     = "storefront"
  environment = "production"
  owner       = "webops"
  cost_centre = "ecommerce"
}

module "database" {
  source = "github.com/kingletas/terraform-aws-modules//modules/aurora-cluster?ref=v0.6.0"

  name       = module.context.prefix
  subnet_ids = values(module.vpc.private_subnet_ids)

  backup_retention_period = module.context.defaults.backup_retention_days
  deletion_protection     = module.context.defaults.deletion_protection
  skip_final_snapshot     = module.context.defaults.skip_final_snapshot
  tags                    = module.context.tags
}
```

## What `defaults` decides

Without a shared table, each stack carries its own environment-to-setting map and makes its own decision about retention, multi-AZ and deletion protection. Here it is one table:

| | dev | staging | uat | production |
|---|---|---|---|---|
| `multi_az` | no | no | no | **yes** |
| `deletion_protection` | no | no | yes | **yes** |
| `skip_final_snapshot` | yes | yes | no | **no** |
| `backup_retention_days` | 1 | 7 | 14 | **30** |
| `log_retention_days` | 30 | 90 | 90 | **365** |
| `single_nat_gateway` | yes | yes | yes | **no** |
| `min` / `desired` / `max` capacity | 1 / 1 / 2 | 1 / 2 / 4 | 2 / 2 / 4 | **2 / 3 / 12** |

A stack reads these rather than writing another conditional. Where a stack genuinely differs, it sets that one value itself, and the difference is visible in the code.

## Three name shapes

AWS naming rules differ between services, so the module exports three forms of the same name:

- **`prefix`**: `project-environment-component` (the component is left out when not set). Most resources take this.
- **`short_prefix`**: the prefix truncated to 24 characters, for a load balancer or an OpenSearch domain, where AWS caps the name and a module appends a suffix.
- **`compact_prefix`**: the prefix with hyphens removed, for names that reject hyphens.

Computing these once keeps names for the same thing consistent across stacks.

## Notes

- **Production gets the tag `Backup = true` automatically.** A tag-selected backup plan then covers production and nothing else, with no environment logic in the plan.
- Use `is_production` rather than comparing the environment string in each stack.
- `name` maps a few common suffixes to full names, such as `name["alb"]` and `name["bastion"]`. The suffixes are `vpc`, `alb`, `web`, `app`, `data`, `cache`, `search`, `queue`, `bastion`, `cron`, `admin` and `builder`.
- `environment` must be `dev`, `staging`, `uat` or `production`, so a typo is a plan error rather than a stack named `storefront-produciton`.
- `extra_tags` is merged last, so a key there overrides a generated tag.

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
