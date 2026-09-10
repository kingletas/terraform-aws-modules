# alb

An application load balancer with target groups, an HTTPS listener, and HTTP answering with a redirect.

## Usage

```hcl
module "public" {
  source = "github.com/kingletas/terraform-aws-modules//modules/alb?ref=v0.1.0"

  name       = "platform-public"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = values(module.vpc.public_subnet_ids)

  security_group_ids = [module.alb_sg.id]
  certificate_arn    = module.certificate.validated_arn

  target_groups = {
    app = {
      port              = 8080
      health_check_path = "/healthz"
    }
    admin = {
      port              = 9000
      health_check_path = "/healthz"
    }
  }

  default_target_group = "app"

  listener_rules = {
    admin = {
      priority      = 100
      target_group  = "admin"
      path_patterns = ["/admin/*"]
    }
  }
}
```

## Notes

- **Without `certificate_arn` the module creates an HTTP listener only.** That is fine for a private internal service and wrong for anything else.
- A target group's `name` is derived from the load balancer name and the key, truncated to 32 characters. Two long keys sharing a prefix can collide.
- `deregistration_delay` is how long the load balancer waits for in-flight requests before removing a target. Lower it for fast deploys, raise it for long requests.
- Listener rules are evaluated in `priority` order, lowest first. Leave gaps so a rule can be inserted later.

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
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the load balancer. AWS caps this at 32 characters. | `string` | n/a | yes |
| vpc\_id | VPC the target groups belong to. | `string` | n/a | yes |
| subnet\_ids | Subnets to place the load balancer in. Public subnets for an internet-facing one, at least two zones. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups on the load balancer. | `list(string)` | `[]` | no |
| internal | Make the load balancer reachable only from inside the VPC. | `bool` | `false` | no |
| certificate\_arn | ACM certificate for the HTTPS listener. Null creates an HTTP listener only, which you should not do in production. | `string` | `null` | no |
| additional\_certificate\_arns | Extra certificates on the HTTPS listener, for serving several host names. | `list(string)` | `[]` | no |
| ssl\_policy | TLS policy. The TLS13 policies are current; the older ones exist for clients that cannot negotiate it. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| redirect\_http\_to\_https | Answer plain HTTP with a permanent redirect to HTTPS. Ignored without a certificate. | `bool` | `true` | no |
| target\_groups | Target groups keyed by a stable name. One of them must be named as the default\_target\_group. | <pre>map(object({<br/>    port                 = number<br/>    protocol             = optional(string, "HTTP")<br/>    protocol_version     = optional(string, "HTTP1")<br/>    target_type          = optional(string, "instance")<br/>    deregistration_delay = optional(number, 30)<br/>    slow_start           = optional(number, 0)<br/>    stickiness_enabled   = optional(bool, false)<br/>    stickiness_duration  = optional(number, 86400)<br/><br/>    health_check_path                = optional(string, "/")<br/>    health_check_matcher             = optional(string, "200")<br/>    health_check_interval            = optional(number, 30)<br/>    health_check_timeout             = optional(number, 5)<br/>    health_check_healthy_threshold   = optional(number, 2)<br/>    health_check_unhealthy_threshold = optional(number, 2)<br/>  }))</pre> | n/a | yes |
| default\_target\_group | Which target group receives traffic that matches no listener rule. | `string` | n/a | yes |
| listener\_rules | Rules on the HTTPS listener, keyed by a stable name. Lower priority numbers are evaluated first. | <pre>map(object({<br/>    priority      = number<br/>    target_group  = string<br/>    host_headers  = optional(list(string))<br/>    path_patterns = optional(list(string))<br/>    http_headers  = optional(map(list(string)))<br/>  }))</pre> | `{}` | no |
| access\_logs | S3 bucket for access logs. The bucket policy must already allow the load balancing service to write. | <pre>object({<br/>    bucket  = string<br/>    prefix  = optional(string)<br/>    enabled = optional(bool, true)<br/>  })</pre> | `null` | no |
| idle\_timeout | Seconds a connection may sit idle. Raise it above your slowest backend response or the client sees a 504. | `number` | `60` | no |
| enable\_deletion\_protection | Refuse to delete the load balancer until this is turned off. | `bool` | `true` | no |
| drop\_invalid\_header\_fields | Drop malformed headers instead of forwarding them, which closes a class of request smuggling. | `bool` | `true` | no |
| enable\_http2 | Serve HTTP/2 to clients that ask for it. | `bool` | `true` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the load balancer. |
| dns\_name | DNS name of the load balancer. Point an alias record at this, never a CNAME to an IP. |
| zone\_id | Hosted zone ID of the load balancer, for a Route 53 alias record. |
| arn\_suffix | ARN suffix, which is what CloudWatch metric dimensions use. |
| target\_group\_arns | Target group ARNs, keyed by the name you gave each one. |
| target\_group\_arn\_suffixes | Target group ARN suffixes, for CloudWatch metric dimensions. |
| https\_listener\_arn | ARN of the HTTPS listener, or null when no certificate was given. |
| http\_listener\_arn | ARN of the HTTP listener. |
<!-- END_TF_DOCS -->
