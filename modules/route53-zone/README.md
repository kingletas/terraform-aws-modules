# route53-zone

A hosted zone with its records and health checks, public or private.

## Usage

```hcl
module "zone" {
  source = "github.com/kingletas/terraform-aws-modules//modules/route53-zone?ref=v0.5.0"

  name = "example.com"

  records = {
    apex = {
      name          = "example.com"
      type          = "A"
      alias_name    = module.alb.dns_name
      alias_zone_id = module.alb.zone_id
    }

    mail = {
      name    = "example.com"
      type    = "MX"
      records = ["10 mail.example.com"]
    }
  }
}
```

## Alias records, not CNAMEs

An alias points at an AWS resource, resolves for free, and **can sit at the zone apex**. A CNAME cannot, because DNS forbids a CNAME alongside the SOA and NS records that must exist there.

Aliases also follow the target. When a load balancer's addresses change, the alias is already correct.

## Notes

- **A new public zone answers for nobody until the registrar is given its `name_servers`.** Creating the zone is the easy half.
- A private zone answers only inside the VPCs you list, and those VPCs need DNS support and DNS hostnames enabled.
- Query logging is public zones only, and the log group must be in us-east-1.

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
| [aws_route53_health_check.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_health_check) | resource |
| [aws_route53_query_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_query_log) | resource |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Domain name for the zone, such as example.com. | `string` | n/a | yes |
| comment | What this zone is for. | `string` | `null` | no |
| private\_vpc\_ids | VPCs the zone answers inside. Empty makes the zone public. | `list(string)` | `[]` | no |
| force\_destroy | Let terraform destroy delete a zone that still holds records it did not create. | `bool` | `false` | no |
| records | Records keyed by a stable name. An alias points at an AWS resource and is free to resolve; a CNAME is billed per query and cannot sit at the apex. | <pre>map(object({<br/>    name    = string<br/>    type    = string<br/>    ttl     = optional(number, 300)<br/>    records = optional(list(string), [])<br/><br/>    alias_name                   = optional(string)<br/>    alias_zone_id                = optional(string)<br/>    alias_evaluate_target_health = optional(bool, true)<br/><br/>    set_identifier  = optional(string)<br/>    weight          = optional(number)<br/>    failover        = optional(string)<br/>    health_check_id = optional(string)<br/>  }))</pre> | `{}` | no |
| health\_checks | Health checks keyed by a stable name, for failover records. | <pre>map(object({<br/>    fqdn              = optional(string)<br/>    ip_address        = optional(string)<br/>    port              = optional(number, 443)<br/>    type              = optional(string, "HTTPS")<br/>    resource_path     = optional(string, "/")<br/>    failure_threshold = optional(number, 3)<br/>    request_interval  = optional(number, 30)<br/>    regions           = optional(list(string))<br/>  }))</pre> | `{}` | no |
| enable\_query\_logging | Log every query against a public zone. The log group must be in us-east-1 and named /aws/route53/<zone>. | `bool` | `false` | no |
| query\_log\_group\_arn | CloudWatch log group for query logs. Required when enable\_query\_logging is on. | `string` | `null` | no |
| tags | Tags applied to the zone and its health checks. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| zone\_id | ID of the hosted zone. |
| arn | ARN of the hosted zone. |
| name | Domain name of the zone. |
| name\_servers | Name servers for the zone. Give these to the registrar, or a public zone answers for nobody. |
| record\_fqdns | Fully qualified names of the records created, keyed by the name you gave each one. |
| health\_check\_ids | Health check IDs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
