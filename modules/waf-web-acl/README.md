# waf-web-acl

A WAF web ACL with AWS managed rule groups, rate limits and IP lists, logging with credentials redacted.

## Usage

```hcl
module "waf" {
  source = "github.com/kingletas/terraform-aws-modules//modules/waf-web-acl?ref=v0.6.0"

  name  = "platform-public"
  scope = "REGIONAL"

  managed_rule_groups = {
    AWSManagedRulesCommonRuleSet         = { priority = 10, count_only = true }
    AWSManagedRulesKnownBadInputsRuleSet = { priority = 20 }
  }

  rate_limits = {
    login = {
      priority              = 5
      limit                 = 300
      scope_down_uri_prefix = "/login"
    }
  }

  log_destination_arns = [aws_cloudwatch_log_group.waf.arn]
  associations         = { alb = module.alb.arn }
}
```

## Start in count mode

`count_only = true` records what a rule group *would* have blocked without blocking anything. The common rule set has real false positives against ordinary applications: file uploads and rich text bodies trip it regularly.

Deploy in count mode, read the sampled requests for a week, then enforce. Enforcing first means finding out from your users.

## Notes

- **A CLOUDFRONT-scoped web ACL must be created in us-east-1**, and it is attached from the distribution rather than by an association here.
- A CloudWatch log group used as a destination must be named starting `aws-waf-logs-`. WAF rejects anything else, and the message does not explain why.
- `authorization` and `cookie` are redacted from logs by default, which is what stops the WAF log becoming a credential store.
- The web ACL is capped at 5000 capacity units. The `capacity` output tells you how close you are.

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
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Web ACL name. | `string` | n/a | yes |
| description | What this web ACL protects. | `string` | `null` | no |
| scope | REGIONAL for a load balancer or API Gateway. CLOUDFRONT must be created in us-east-1. | `string` | `"REGIONAL"` | no |
| default\_action | What happens to a request no rule matched: allow or block. | `string` | `"allow"` | no |
| managed\_rule\_groups | AWS managed rule groups keyed by group name. Start with count\_only, read the metrics, then enforce. | <pre>map(object({<br/>    priority       = number<br/>    vendor_name    = optional(string, "AWS")<br/>    count_only     = optional(bool, false)<br/>    excluded_rules = optional(list(string), [])<br/>  }))</pre> | <pre>{<br/>  "AWSManagedRulesAmazonIpReputationList": {<br/>    "priority": 30<br/>  },<br/>  "AWSManagedRulesCommonRuleSet": {<br/>    "priority": 10<br/>  },<br/>  "AWSManagedRulesKnownBadInputsRuleSet": {<br/>    "priority": 20<br/>  }<br/>}</pre> | no |
| rate\_limits | Rate-based rules keyed by a stable name. The limit is requests per five minutes from one key. | <pre>map(object({<br/>    priority              = number<br/>    limit                 = number<br/>    aggregate_key_type    = optional(string, "IP")<br/>    action                = optional(string, "block")<br/>    scope_down_uri_prefix = optional(string)<br/>  }))</pre> | `{}` | no |
| ip\_allow\_lists | IP sets that are always allowed, keyed by a stable name. Give these low priority numbers so they run first. | <pre>map(object({<br/>    priority = number<br/>    arn      = string<br/>  }))</pre> | `{}` | no |
| ip\_block\_lists | IP sets that are always blocked, keyed by a stable name. | <pre>map(object({<br/>    priority = number<br/>    arn      = string<br/>  }))</pre> | `{}` | no |
| log\_destination\_arns | Where to send request logs: a CloudWatch log group whose name starts aws-waf-logs-, a Firehose, or an S3 bucket. | `list(string)` | `[]` | no |
| redacted\_header\_names | Headers to redact from logs. Authorization and cookie are the ones that matter. | `list(string)` | <pre>[<br/>  "authorization",<br/>  "cookie"<br/>]</pre> | no |
| associations | Load balancer or API Gateway stage ARNs to attach the web ACL to, keyed by a stable name. The keys must be known at plan; the ARNs need not be. CloudFront is attached from the distribution instead. | `map(string)` | `{}` | no |
| tags | Tags applied to the web ACL. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the web ACL. A CloudFront distribution takes this as web\_acl\_id. |
| id | ID of the web ACL. |
| name | Name of the web ACL. |
| capacity | Capacity units the rules consume. A web ACL is capped at 5000, so this is what limits how many rules fit. |
<!-- END_TF_DOCS -->
