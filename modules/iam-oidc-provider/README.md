# iam-oidc-provider

An OpenID Connect provider in IAM, so a CI system gets short-lived AWS credentials instead of a stored access key.

## Usage

```hcl
module "github" {
  source = "github.com/kingletas/terraform-aws-modules//modules/iam-oidc-provider?ref=v0.3.1"

  url        = "https://token.actions.githubusercontent.com"
  client_ids = ["sts.amazonaws.com"]
}

module "deploy_role" {
  source = "github.com/kingletas/terraform-aws-modules//modules/iam-role?ref=v0.3.1"

  name = "github-deploy"

  trusted_oidc_providers = {
    github = {
      provider_arn = module.github.arn
      audience_key = module.github.audience_key
      audiences    = ["sts.amazonaws.com"]
      subject_key  = module.github.subject_key
      subjects     = ["repo:your-org/your-repo:ref:refs/heads/main"]
    }
  }

  managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
```

The provider is created once per account. The roles that trust it are created per job, per repository or per environment, which is [`iam-role`](../iam-role).

## Always narrow the subject

The audience alone is not a restriction worth having. Every GitHub Actions workflow in the world requests `sts.amazonaws.com`, so a role that checks only the audience can be assumed by **any repository on GitHub**. What makes the trust yours is the `sub` claim.

| `subjects` | Who can assume the role |
|---|---|
| `repo:your-org/*` | Anyone in your organization, including a fork opened as a pull request |
| `repo:your-org/your-repo:ref:refs/heads/main` | That repository, on that branch |
| `repo:your-org/your-repo:environment:production` | That repository, in an environment with its own approvers |

[`iam-role`](../iam-role) refuses a trust with no `subjects`, a subject made only of wildcards, and a GitHub subject that does not open with an owner or repository claim and a literal value (see its README for the accepted claims), so the audience-only trust and `repo:*` cannot be planned. The last two rows are the ones to reach for. An environment is the stronger of them, because GitHub can require a human approval before the job that assumes the role ever starts.

`audience_key` and `subject_key` are outputs rather than something you write, so the issuer host is stated once and the trust policy cannot disagree with the provider it names.

## Thumbprints are usually not yours to manage

`thumbprints` defaults to null, which lets AWS verify the issuer against its own trust store. That covers GitHub, GitLab and the other well-known providers, and it means a rotated intermediate certificate does not silently break every deployment at two in the morning.

Set them only for a private issuer AWS does not know. If you do, they are yours to rotate.

## Notes

- **The URL must match the `iss` claim character for character**, which is why a trailing slash is refused at plan rather than discovered as an authentication failure later.
- **One provider per issuer per account.** A second one for the same URL fails. In an organization, that means either a provider in every account, or one role in a shared account that the others trust in turn.
- Removing the provider does not remove the roles that trust it. Those keep a trust policy naming an ARN that no longer resolves, and every assume fails.

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
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| url | Issuer URL, such as https://token.actions.githubusercontent.com. It must match the iss claim in the token exactly, with no trailing slash. | `string` | n/a | yes |
| client\_ids | Audiences the provider may issue for, which is the aud claim. GitHub Actions uses sts.amazonaws.com. | `list(string)` | n/a | yes |
| thumbprints | SHA-1 thumbprints of the issuer's certificate chain. Leave null for a provider AWS verifies against its own trust store, which includes GitHub and GitLab. | `list(string)` | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the provider. This is the provider\_arn an iam-role trust takes. |
| url | Issuer URL, as registered. |
| host | Issuer host, which is what the condition keys are built from. |
| audience\_key | Condition key holding the aud claim, ready for an iam-role trust. |
| subject\_key | Condition key holding the sub claim, which is what narrows a trust to one repository, branch or environment. |
<!-- END_TF_DOCS -->
