# nlb

A network load balancer, for TCP and TLS traffic that an application load balancer cannot carry.

## Usage

```hcl
module "internal" {
  source = "github.com/kingletas/terraform-aws-modules//modules/nlb?ref=v0.7.0"

  name       = "platform-internal"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = values(module.vpc.private_subnet_ids)
  internal   = true

  target_groups = {
    postgres = {
      port        = 5432
      protocol    = "TCP"
      target_type = "ip"
    }
  }

  listeners = {
    postgres = {
      port         = 5432
      target_group = "postgres"
    }
  }
}
```

## Notes

- **A network load balancer created without security groups can never be given one.** The association is fixed at creation, so pass `security_group_ids` even if the list is provisional.
- `preserve_client_ip` changes what the target sees as the source address. It is on by default for instance targets and off for IP targets, and switching it can break a target's own allow-lists.
- `enable_cross_zone_load_balancing` is off by default in AWS and on here. It distributes traffic evenly and bills for cross-zone data transfer.
- `name` must be 2 to 32 letters, digits or hyphens, and cannot start or end with a hyphen. The plan checks this.
- **Target group names are generated**: the load balancer name and the target group key, cut to fit, plus a short hash of the key, VPC, port, protocol and target type. Changing any of those creates the new target group under a new name before the old one is destroyed, so the listener moves across without a name collision.
- Health checks default to TCP, which only proves something is listening. Use HTTP with a path where the target can serve one.

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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the load balancer. AWS caps this at 32 characters. | `string` | n/a | yes |
| vpc\_id | VPC the target groups belong to. | `string` | n/a | yes |
| subnet\_ids | Subnets to place the load balancer in. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups on the load balancer. A network load balancer created without any can never have one added. | `list(string)` | `[]` | no |
| internal | Make the load balancer reachable only from inside the VPC. | `bool` | `true` | no |
| enable\_cross\_zone\_load\_balancing | Spread traffic across zones evenly. Off by default in AWS, and cross-zone data transfer is billed. | `bool` | `true` | no |
| listeners | Listeners keyed by a stable name. TLS listeners need a certificate\_arn. | <pre>map(object({<br/>    port            = number<br/>    protocol        = optional(string, "TCP")<br/>    target_group    = string<br/>    certificate_arn = optional(string)<br/>    ssl_policy      = optional(string, "ELBSecurityPolicy-TLS13-1-2-2021-06")<br/>  }))</pre> | n/a | yes |
| target\_groups | Target groups keyed by a stable name. | <pre>map(object({<br/>    port                 = number<br/>    protocol             = optional(string, "TCP")<br/>    target_type          = optional(string, "instance")<br/>    deregistration_delay = optional(number, 30)<br/>    preserve_client_ip   = optional(bool)<br/>    proxy_protocol_v2    = optional(bool, false)<br/><br/>    health_check_protocol            = optional(string, "TCP")<br/>    health_check_port                = optional(string, "traffic-port")<br/>    health_check_path                = optional(string)<br/>    health_check_interval            = optional(number, 30)<br/>    health_check_healthy_threshold   = optional(number, 3)<br/>    health_check_unhealthy_threshold = optional(number, 3)<br/>  }))</pre> | n/a | yes |
| access\_logs | S3 bucket for access logs. Only recorded for TLS listeners. | <pre>object({<br/>    bucket  = string<br/>    prefix  = optional(string)<br/>    enabled = optional(bool, true)<br/>  })</pre> | `null` | no |
| enable\_deletion\_protection | Refuse to delete the load balancer until this is turned off. | `bool` | `true` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the load balancer. |
| dns\_name | DNS name of the load balancer. |
| zone\_id | Hosted zone ID, for a Route 53 alias record. |
| arn\_suffix | ARN suffix, which is what CloudWatch metric dimensions use. |
| target\_group\_arns | Target group ARNs, keyed by the name you gave each one. |
| listener\_arns | Listener ARNs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
