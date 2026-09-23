# cognito-user-pool

A user pool with its app clients and user enumeration closed, with threat protection available on the Plus plan.

## Usage

```hcl
module "users" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cognito-user-pool?ref=v0.6.0"

  name          = "platform-users"
  domain_prefix = "platform-login"

  clients = {
    web = {
      callback_urls = ["https://app.example.com/callback"]
      logout_urls   = ["https://app.example.com/"]
    }
  }
}
```

## Notes

- **`prevent_user_existence_errors` is on for every client by default.** Without it a failed login says whether the account exists, which turns the login form into a way to enumerate your users.
- **`username_attributes` cannot be changed after the pool is created.** Getting it wrong means a new pool and migrating every user.
- A custom attribute can never be removed or retyped. Adding one is a decision you keep.
- `generate_secret` is for server-side clients only. A browser or mobile app cannot keep a secret, and including one there is a leak rather than a protection.
- **Threat protection needs the Plus feature plan.** `user_pool_tier` defaults to `ESSENTIALS`, and `advanced_security_mode` defaults to `OFF` because AWS refuses `AUDIT` and `ENFORCED` on any plan but Plus. To turn it on, set `user_pool_tier = "PLUS"`, which is billed per monthly active user, and start with `AUDIT`: it records risk without acting on it. The module refuses either mode at plan on any other tier.
- **`user_pool_tier` is always set on the pool.** A pool imported into this module on a different plan (Lite, for example) moves to the value of `user_pool_tier` on the next apply, which changes the bill.

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
| [aws_cognito_user_pool.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool) | resource |
| [aws_cognito_user_pool_client.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_client) | resource |
| [aws_cognito_user_pool_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user_pool_domain) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | User pool name. | `string` | n/a | yes |
| domain\_prefix | Prefix for the hosted UI domain, giving <prefix>.auth.<region>.amazoncognito.com. Null creates no hosted domain. | `string` | `null` | no |
| custom\_domain | Custom domain for the hosted UI. Needs an ACM certificate in us-east-1 and an A record afterwards. | `string` | `null` | no |
| custom\_domain\_certificate\_arn | ACM certificate for the custom domain, which must live in us-east-1. | `string` | `null` | no |
| username\_attributes | Attributes usable as a username: email, phone\_number, or both. Cannot be changed after creation. | `list(string)` | <pre>[<br/>  "email"<br/>]</pre> | no |
| auto\_verified\_attributes | Attributes Cognito verifies by sending a code. | `list(string)` | <pre>[<br/>  "email"<br/>]</pre> | no |
| password\_policy | Password rules. Length does more work than character classes, so raise the minimum before adding requirements. | <pre>object({<br/>    minimum_length                   = optional(number, 12)<br/>    require_lowercase                = optional(bool, true)<br/>    require_uppercase                = optional(bool, true)<br/>    require_numbers                  = optional(bool, true)<br/>    require_symbols                  = optional(bool, true)<br/>    temporary_password_validity_days = optional(number, 3)<br/>  })</pre> | `{}` | no |
| mfa\_configuration | OFF, ON to require it, or OPTIONAL to let users choose. | `string` | `"OPTIONAL"` | no |
| software\_token\_mfa | Allow authenticator apps for the second factor. Preferred over SMS, which is interceptable. | `bool` | `true` | no |
| user\_pool\_tier | Feature plan: LITE, ESSENTIALS or PLUS. Threat protection needs PLUS, which is billed per monthly active user. | `string` | `"ESSENTIALS"` | no |
| advanced\_security\_mode | Threat protection: OFF, AUDIT to record risk, or ENFORCED to act on it. AUDIT and ENFORCED need user\_pool\_tier PLUS. | `string` | `"OFF"` | no |
| deletion\_protection | Refuse to delete the pool until this is turned off. Deleting a pool deletes every user in it. | `bool` | `true` | no |
| custom\_attributes | Custom attributes keyed by name. These cannot be removed or retyped once the pool exists. | <pre>map(object({<br/>    type       = optional(string, "String")<br/>    mutable    = optional(bool, true)<br/>    min_length = optional(number)<br/>    max_length = optional(number)<br/>  }))</pre> | `{}` | no |
| clients | App clients keyed by name. generate\_secret is for server-side clients only; a browser or mobile app cannot keep one. | <pre>map(object({<br/>    generate_secret               = optional(bool, false)<br/>    callback_urls                 = optional(list(string), [])<br/>    logout_urls                   = optional(list(string), [])<br/>    allowed_oauth_flows           = optional(list(string), ["code"])<br/>    allowed_oauth_scopes          = optional(list(string), ["openid", "email", "profile"])<br/>    supported_identity_providers  = optional(list(string), ["COGNITO"])<br/>    explicit_auth_flows           = optional(list(string), ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"])<br/>    access_token_validity_minutes = optional(number, 60)<br/>    id_token_validity_minutes     = optional(number, 60)<br/>    refresh_token_validity_days   = optional(number, 30)<br/>    prevent_user_existence_errors = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to the user pool. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the user pool. |
| arn | ARN of the user pool, which an API Gateway authorizer references. |
| endpoint | Token and JWKS endpoint host for the pool. |
| domain | Hosted UI domain, or null when none was created. |
| cloudfront\_distribution\_arn | CloudFront distribution behind a custom domain, which the A record must alias to. |
| client\_ids | App client IDs, keyed by client name. |
| client\_secrets | App client secrets, keyed by client name. Only populated for clients that generate one. |
<!-- END_TF_DOCS -->
