# organization-policy

One organizational policy and everything it is attached to. Usually a service control policy: the ceiling on what an account may do, whatever its own IAM says.

## Usage

```hcl
data "aws_iam_policy_document" "guardrails" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyDisablingTheAuditTrail"
    effect    = "Deny"
    actions   = ["cloudtrail:StopLogging", "cloudtrail:DeleteTrail"]
    resources = ["*"]
  }
}

module "guardrails" {
  source = "github.com/kingletas/terraform-aws-modules//modules/organization-policy?ref=v0.7.0"

  name        = "baseline-guardrails"
  description = "Things no account may do, including an administrator."
  content     = data.aws_iam_policy_document.guardrails.json

  targets = merge(
    { root = module.organization.root_id },
    module.organization.organizational_unit_ids,
  )
}
```

## A service control policy is a ceiling, not a grant

It can only take permissions away. An account still needs IAM to allow an action, and the policy decides whether that allow survives. Nothing is granted by attaching one.

Two consequences that surprise people:

- **An account administrator cannot work around it.** That is the point, and it is also why a policy that denies too much locks out the people who would fix it.
- **The management account is not covered.** Service control policies do not apply there, whatever they are attached to. Anything running in the management account is outside every guardrail, which is the argument for deploying nothing into it.

## Attach to units, not accounts, wherever you can

`targets` is keyed by a name you choose so that detaching one does not disturb the others. Prefer an organizational unit as the target: a new account placed in that unit inherits the policy on creation, with nobody remembering to attach anything.

Attaching to the root applies the policy to every account in the organization except the management account. That is the right place for the handful of denials that are true everywhere, and the wrong place for anything an exception will ever be wanted for, because the root has no exceptions.

## The policy type has to be enabled first

A policy can only exist once its type is enabled on the organization, which is `enabled_policy_types` on [`organization`](../organization). Enabling a type costs nothing and attaches nothing.

**Enabling `SERVICE_CONTROL_POLICY` attaches AWS's `FullAWSAccess` policy to everything by default.** That default is what makes a deny-only policy work: without an allow somewhere, an SCP ceiling of deny-only would block everything. If you replace `FullAWSAccess` with an allow-list of your own, test it on one unit before the root.

## Notes

- `skip_destroy` leaves the policy and its attachments in place when Terraform stops managing them. Useful when handing a policy to another team, and a way to orphan things if used carelessly.
- A service control policy document is capped at 5,120 characters including whitespace. `jsonencode` of a compact document is well inside that; a long allow-list is not.
- Validate the JSON, not just its syntax. This module checks the content parses. It cannot check that the policy says what you meant.

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
| [aws_organizations_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Policy name, unique within the organization. | `string` | n/a | yes |
| description | What the policy is for. This is what someone reads when a call is denied and they go looking for why. | `string` | n/a | yes |
| content | The policy document as JSON. A service control policy uses IAM policy syntax, so aws\_iam\_policy\_document builds one. | `string` | n/a | yes |
| type | Policy type. The organization must have this type enabled before a policy of it can exist. | `string` | `"SERVICE_CONTROL_POLICY"` | no |
| targets | What the policy attaches to, keyed by a name you choose, each value a root, organizational unit or account ID. Keying by name means detaching one target does not disturb the others. | `map(string)` | `{}` | no |
| skip\_destroy | Leave the policy in place when Terraform stops managing it, rather than deleting it. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | Identifier of the policy. |
| arn | ARN of the policy. |
| name | Name of the policy. |
| attachment\_target\_ids | What the policy is attached to, keyed the way the targets were declared. |
<!-- END_TF_DOCS -->
