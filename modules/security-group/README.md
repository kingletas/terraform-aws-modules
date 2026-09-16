# security-group

A security group whose rules are separate resources, keyed by name.

Terraform's older inline `ingress` and `egress` blocks force a replacement of the whole group whenever a rule changes, and they cannot carry a per-rule description. This module uses `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` instead, so adding a rule adds a rule.

Because rules are keyed by a name you choose, removing the third rule from a list does not renumber the ones after it.

## Usage

```hcl
module "app_sg" {
  source = "github.com/kingletas/terraform-aws-modules//modules/security-group?ref=v0.4.0"

  name        = "platform-app"
  description = "Application instances"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https_from_alb = {
      description                  = "HTTPS from the load balancer"
      ip_protocol                  = "tcp"
      from_port                    = 443
      to_port                      = 443
      referenced_security_group_id = module.alb_sg.id
    }

    peers = {
      description = "Instances in this group reaching each other"
      ip_protocol = "-1"
      self        = true
    }
  }

  tags = {
    Environment = "production"
  }
}
```

## Rule sources

Every rule needs exactly one source, or for an egress rule one destination. The module checks this at plan time for both:

| Field | Use it for |
|---|---|
| `cidr_ipv4` | An address range |
| `cidr_ipv6` | An IPv6 range |
| `referenced_security_group_id` | Another security group |
| `prefix_list_id` | A managed prefix list, such as an S3 gateway endpoint |
| `self` | Members of this same group |

Set `ip_protocol = "-1"` for all protocols; the port fields are then ignored. Otherwise `ip_protocol` is `tcp`, `udp`, `icmp`, `icmpv6` or a protocol number from 0 to 255. A `tcp` or `udp` rule needs `from_port` and `to_port` between 0 and 65535, with `from_port` no greater than `to_port`. For `icmp` and `icmpv6` the two fields are the type and code, from -1 to 255.

## Egress

With no `egress_rules` the module adds one rule allowing all outbound IPv4 traffic, which is what AWS does for a new group. Supplying `egress_rules` **replaces** that rule rather than adding to it. Set `allow_all_egress = false` to have neither.

## Notes

- The group is created with `name_prefix` and `create_before_destroy`, so a change that forces replacement does not collide with the existing name.
- Every ingress rule needs a non-empty description. This is checked at plan time.

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
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the security group. | `string` | n/a | yes |
| description | What this security group is for. AWS will not let you change it later without replacing the group. | `string` | n/a | yes |
| vpc\_id | VPC the security group belongs to. | `string` | n/a | yes |
| ingress\_rules | Inbound rules keyed by a stable name. Give each rule exactly one source: a CIDR, another security group, a prefix list, or self. | <pre>map(object({<br/>    description                  = string<br/>    from_port                    = optional(number)<br/>    to_port                      = optional(number)<br/>    ip_protocol                  = optional(string, "tcp")<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    prefix_list_id               = optional(string)<br/>    self                         = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| egress\_rules | Outbound rules keyed by a stable name. Give each rule exactly one destination: a CIDR, another security group, a prefix list, or self. Leave empty to allow all outbound IPv4 traffic. | <pre>map(object({<br/>    description                  = string<br/>    from_port                    = optional(number)<br/>    to_port                      = optional(number)<br/>    ip_protocol                  = optional(string, "tcp")<br/>    cidr_ipv4                    = optional(string)<br/>    cidr_ipv6                    = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>    prefix_list_id               = optional(string)<br/>    self                         = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| allow\_all\_egress | Add a rule permitting all outbound IPv4 traffic. Ignored when egress\_rules is non-empty. | `bool` | `true` | no |
| tags | Tags applied to the security group. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the security group. |
| arn | ARN of the security group. |
| name | Generated name of the security group. |
<!-- END_TF_DOCS -->
