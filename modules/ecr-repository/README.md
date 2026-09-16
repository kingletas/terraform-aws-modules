# ecr-repository

A container registry with immutable tags and a lifecycle policy, so old images do not accumulate at a dollar a gigabyte.

## Usage

```hcl
module "api_image" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ecr-repository?ref=v0.3.1"

  name                       = "platform/api"
  untagged_image_expiry_days = 7
  max_tagged_images          = 30
}
```

## Why tags are immutable by default

With mutable tags, `v1.4.2` can be moved to a different image after it was deployed. What is running then no longer matches what that tag meant, and nothing records the change. Immutable tags make a deployed tag a fact.

This does mean a build cannot overwrite `latest`. Push a digest or a build-specific tag instead.

## Notes

- `scan_on_push` reports known vulnerabilities in the image. It does not block the push.
- The lifecycle policy runs asynchronously: expired images disappear within a day or so, not immediately.

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
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Repository name. Slashes are allowed, so team/service works. | `string` | n/a | yes |
| image\_tag\_mutability | IMMUTABLE stops a tag being moved to a different image, which is what makes a deployed tag mean something. | `string` | `"IMMUTABLE"` | no |
| scan\_on\_push | Scan each pushed image for known vulnerabilities. | `bool` | `true` | no |
| kms\_key\_arn | KMS key for encryption at rest. Null uses AES256, which is still encryption. | `string` | `null` | no |
| force\_delete | Let terraform destroy delete a repository that still holds images. | `bool` | `false` | no |
| untagged\_image\_expiry\_days | Expire untagged images after this many days. Set to 0 to keep them forever. | `number` | `14` | no |
| max\_tagged\_images | Keep at most this many tagged images. Set to 0 for no limit. | `number` | `50` | no |
| tag\_prefixes\_to\_keep | Tag prefixes the count limit applies to. Empty applies it to any tagged image. | `list(string)` | `[]` | no |
| attach\_policy | Attach policy\_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply. | `bool` | `false` | no |
| policy\_json | Repository policy, for granting pull access to another account. | `string` | `null` | no |
| tags | Tags applied to the repository. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| name | Name of the repository. |
| arn | ARN of the repository. |
| repository\_url | URL to push and pull from, which is what a docker tag needs. |
| registry\_id | Account ID of the registry holding this repository. |
<!-- END_TF_DOCS -->
