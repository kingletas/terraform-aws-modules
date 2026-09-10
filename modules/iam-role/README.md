# iam-role

A role, its trust policy and its attachments, covering service, cross-account and OIDC federation.

## Usage

```hcl
module "task_role" {
  source = "github.com/kingletas/terraform-aws-modules//modules/iam-role?ref=v0.1.0"

  name             = "platform-api-task"
  description      = "Application code for the API service"
  trusted_services = ["ecs-tasks.amazonaws.com"]

  inline_policies = {
    read_config = data.aws_iam_policy_document.read_config.json
  }
}
```

## GitHub Actions without a stored key

An OIDC trust is how a CI workflow gets credentials with nothing stored in the repository:

```hcl
module "deploy_role" {
  source = "github.com/kingletas/terraform-aws-modules//modules/iam-role?ref=v0.1.0"

  name = "platform-deploy"

  trusted_oidc_providers = {
    github = {
      provider_arn = aws_iam_openid_connect_provider.github.arn
      audience_key = "token.actions.githubusercontent.com:aud"
      audiences    = ["sts.amazonaws.com"]
      subject_key  = "token.actions.githubusercontent.com:sub"
      subjects     = ["repo:kingletas/platform:ref:refs/heads/main"]
    }
  }
}
```

**Always set `subjects`.** Without a subject condition the trust accepts a token from *any* repository on GitHub, which hands the role to the entire internet.

## Notes

- `external_id` is the defence against the confused deputy problem, where a third party you trust is tricked into using your role on someone else's behalf. Set it whenever the trusted principal is outside your organisation.
- `permissions_boundary_arn` caps what the role can ever be granted, however its policies change later. It is the useful control when somebody else can attach policies.
- Inline policies live and die with the role; managed policies outlive it and can be shared.

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
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Role name prefix. | `string` | n/a | yes |
| description | What this role is for. | `string` | `null` | no |
| trusted\_services | AWS service principals allowed to assume the role, such as ec2.amazonaws.com. | `list(string)` | `[]` | no |
| trusted\_role\_arns | IAM role or account ARNs allowed to assume the role. | `list(string)` | `[]` | no |
| trusted\_oidc\_providers | OIDC providers allowed to assume the role, keyed by a stable name. This is how a GitHub Actions workflow gets credentials without a stored key. | <pre>map(object({<br/>    provider_arn = string<br/>    audience_key = string<br/>    audiences    = list(string)<br/>    subject_key  = optional(string)<br/>    subjects     = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| require\_mfa | Require multi-factor authentication on assume. Applies to the role and account principals only. | `bool` | `false` | no |
| external\_id | External ID a third party must present on assume. The defence against the confused deputy problem. | `string` | `null` | no |
| max\_session\_duration | Longest session in seconds, between one and twelve hours. | `number` | `3600` | no |
| managed\_policy\_arns | Managed policies to attach, keyed by a stable name. The keys must be known at plan, so a policy created in the same configuration can be attached; its ARN need not be. | `map(string)` | `{}` | no |
| inline\_policies | Inline policy documents keyed by policy name. These live and die with the role. | `map(string)` | `{}` | no |
| permissions\_boundary\_arn | Policy capping what this role can ever be granted, however its policies change later. | `string` | `null` | no |
| create\_instance\_profile | Also create an instance profile, which is how an EC2 instance is given the role. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the role. |
| name | Generated name of the role. |
| id | ID of the role, which is the same as its name. |
| unique\_id | Stable unique ID, which does not change if the role is renamed. |
| instance\_profile\_name | Instance profile name, or null when none was created. |
| instance\_profile\_arn | Instance profile ARN, or null when none was created. |
<!-- END_TF_DOCS -->
