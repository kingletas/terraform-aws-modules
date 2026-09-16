# organization

An AWS Organization, the organizational units under it, and the member accounts inside those.

## Usage

```hcl
module "organization" {
  source = "github.com/kingletas/terraform-aws-modules//modules/organization?ref=v0.5.0"

  aws_service_access_principals = ["cloudtrail.amazonaws.com", "sso.amazonaws.com"]

  organizational_units = {
    platform = { children = { shared = {} } }
    workload = { children = { staging = {}, production = {} } }
    sandbox  = {}
  }

  accounts = {
    logging    = { name = "logging", email = "aws+logging@example.com", parent = "platform/shared" }
    staging    = { name = "staging", email = "aws+staging@example.com", parent = "workload/staging" }
    production = { name = "production", email = "aws+production@example.com", parent = "workload/production" }
  }

  tags = { ManagedBy = "terraform" }
}
```

## An account cannot be deleted

This is the one thing to understand before applying. Removing an account from `accounts` does not delete it, because AWS has no such operation. What happens instead depends on `close_on_deletion`:

| `close_on_deletion` | Removing the account from the configuration |
|---|---|
| `false`, the default | Terraform forgets the account. It stays in the organization, unmanaged, still billable |
| `true` | Terraform asks AWS to close it. Closure takes 90 days to complete and cannot be undone |

Neither is obviously right, which is why it is set per account rather than once for the module. A sandbox is a reasonable `true`. A production account is not.

The same applies to anything that would force a replacement. `role_name` and `iam_user_access_to_billing` are read only when the account is created, so both are in `ignore_changes`. Without that, editing either one plans a destroy and create, and the destroy is an account closure.

## Two levels of organizational unit

`organizational_units` is a map of top-level names, each with an optional map of children. AWS allows five levels of nesting. This module offers two.

The reason is that the keys of a `for_each` must be known at plan. A tree of arbitrary depth would have to be built from resource IDs that do not exist until apply, so the first plan of a new organization would fail. Two levels come straight from the variable, so every key is known before anything is created, and removing one unit never renumbers another.

A child is addressed as `parent/child` wherever a unit is named, including in an account's `parent` and in the `organizational_unit_ids` output. An account with `parent = null` sits at the root.

## Adopting an organization that already exists

Most accounts that have ever used Organizations already have one, and creating a second is not possible. Set `create_organization = false` and the module reads the existing organization instead. The units and accounts are still managed from here, and `root_id` still resolves.

Importing existing units and accounts is a separate job. This module will not adopt them for you.

## Enabling a policy type is not attaching a policy

`enabled_policy_types` turns a category on for the organization. It does not create or attach anything, and it costs nothing. Attaching an actual service control policy is [`organization-policy`](../organization-policy).

Both policy types and trusted service access need `feature_set = "ALL"`. A consolidated billing organization gets a shared bill and nothing else, and the module refuses the combination at plan rather than at apply.

## Notes

- **Deploy nothing into the management account.** It is where the organization is administered from, it cannot be restricted by a service control policy the way a member account can, and anything running in it is outside the guardrails every other account is inside.
- **An account email must be one no AWS account has ever used**, including closed ones. Plus-addressing (`aws+production@example.com`) is the usual way to keep them distinct on one mailbox.
- `account_role_arns` gives the ARN to assume in each member account from the management account, which is what a provider alias in a downstream stack needs. The ARNs use the partition the provider runs in, so they are correct in AWS GovCloud (US) and China as well.

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
| [aws_organizations_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization) | resource |
| [aws_organizations_organizational_unit.nested](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.top](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| create\_organization | Create the organization. Set false in an account where one already exists, and the module reads it instead of trying to create a second. | `bool` | `true` | no |
| feature\_set | ALL gives policies and trusted service access. CONSOLIDATED\_BILLING gives a shared bill and nothing else. | `string` | `"ALL"` | no |
| aws\_service\_access\_principals | Service principals allowed to operate across the organization, such as cloudtrail.amazonaws.com or sso.amazonaws.com. A service reaches member accounts only once it is listed here. | `list(string)` | `[]` | no |
| enabled\_policy\_types | Policy types the organization may attach. Service control policies are on by default; the others cost nothing until a policy exists. | `list(string)` | <pre>[<br/>  "SERVICE_CONTROL_POLICY"<br/>]</pre> | no |
| organizational\_units | Organizational units below the root, keyed by name, each with an optional map of children. Two levels, which is what most organisations use; AWS allows five. | <pre>map(object({<br/>    tags = optional(map(string), {})<br/>    children = optional(map(object({<br/>      tags = optional(map(string), {})<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| accounts | Member accounts to create, keyed by a stable name. parent is an organizational unit key, either top or parent/child; null places the account at the root. | <pre>map(object({<br/>    name                       = string<br/>    email                      = string<br/>    parent                     = optional(string)<br/>    role_name                  = optional(string, "OrganizationAccountAccessRole")<br/>    iam_user_access_to_billing = optional(string, "ALLOW")<br/>    close_on_deletion          = optional(bool, false)<br/>    tags                       = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Identifier of the organization. |
| arn | ARN of the organization. |
| root\_id | Identifier of the root, which is what a policy attaches to when it should apply everywhere. |
| management\_account\_id | Account the organization is managed from. Nothing should be deployed into it. |
| organizational\_unit\_ids | Organizational unit IDs keyed the way they were declared, a child as parent/child. This is what a policy module attaches to. |
| organizational\_unit\_arns | Organizational unit ARNs, keyed the same way. |
| account\_ids | Account IDs keyed by the name they were declared under. |
| account\_arns | Account ARNs keyed by the name they were declared under. |
| account\_role\_arns | ARN of the role to assume in each member account from the management account. |
<!-- END_TF_DOCS -->
