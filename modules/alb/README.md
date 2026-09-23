# alb

An application load balancer with target groups, an HTTPS listener, and an optional HTTP listener answering with a redirect.

## Usage

```hcl
module "public" {
  source = "github.com/kingletas/terraform-aws-modules//modules/alb?ref=v0.6.0"

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

- **The HTTPS listener needs `certificate_arn`.** It is on by default (`create_https_listener = true`). Set it to `false` for an HTTP listener only, which is fine for a private internal service and wrong for anything else.
- **The port 80 listener is optional.** `create_http_listener = false` drops it, for a load balancer that only accepts HTTPS (from CloudFront, for example). At least one of the two listeners must stay on. While HTTPS is on, port 80 answers with a permanent redirect unless `redirect_http_to_https = false`.
- **Traffic that matches no rule** goes to `default_target_group`, or gets `default_fixed_response` when that is set. One of the two is required. With a rule on `http_headers`, only requests carrying a shared header reach a target group, which is how an origin behind CloudFront refuses direct traffic.
- Listener rules attach to the HTTPS listener, or to the HTTP listener when HTTPS is off. Each rule names one of the `target_groups` and needs at least one of `host_headers`, `path_patterns` or `http_headers`. Rules are evaluated in `priority` order, lowest first. Leave gaps so a rule can be inserted later.
- **The outputs describe what the listener does**, so a caller's test can check it at plan. `https_listener_default_action` gives the default action's type and fixed-response status. `listener_rules` gives each rule's priority, action, target group key, host headers, path patterns and header names. Header values are left out, since they are usually a shared secret.
- `additional_certificate_arns` is a map keyed by a stable name, so certificates created in the same plan can be attached.
- A target group's name is the load balancer name and the key, truncated, plus a short hash of the settings that force a replacement (VPC, port, protocol, protocol version, target type). A replacement therefore gets a new name and can be created before the old group is destroyed, and two long keys sharing a prefix still differ.
- `deregistration_delay` is how long the load balancer waits for in-flight requests before removing a target. Lower it for fast deploys, raise it for long requests.

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
| create\_https\_listener | Create the HTTPS listener on port 443, which needs certificate\_arn. Turning it off leaves an HTTP listener only, which you should not do in production. | `bool` | `true` | no |
| certificate\_arn | ACM certificate for the HTTPS listener. Required while create\_https\_listener is on. | `string` | `null` | no |
| additional\_certificate\_arns | Extra certificates on the HTTPS listener, keyed by a stable name so the ARNs may be unknown until apply. | `map(string)` | `{}` | no |
| ssl\_policy | TLS policy. The TLS13 policies are current; the older ones exist for clients that cannot negotiate it. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| create\_http\_listener | Create the port 80 listener. Turn it off when nothing can reach port 80, such as a load balancer that accepts only HTTPS from CloudFront. | `bool` | `true` | no |
| redirect\_http\_to\_https | Answer plain HTTP with a permanent redirect to HTTPS. Ignored while create\_https\_listener is off. | `bool` | `true` | no |
| target\_groups | Target groups keyed by a stable name. One of them must be named as the default\_target\_group. | <pre>map(object({<br/>    port                 = number<br/>    protocol             = optional(string, "HTTP")<br/>    protocol_version     = optional(string, "HTTP1")<br/>    target_type          = optional(string, "instance")<br/>    deregistration_delay = optional(number, 30)<br/>    slow_start           = optional(number, 0)<br/>    stickiness_enabled   = optional(bool, false)<br/>    stickiness_duration  = optional(number, 86400)<br/><br/>    health_check_path                = optional(string, "/")<br/>    health_check_matcher             = optional(string, "200")<br/>    health_check_interval            = optional(number, 30)<br/>    health_check_timeout             = optional(number, 5)<br/>    health_check_healthy_threshold   = optional(number, 2)<br/>    health_check_unhealthy_threshold = optional(number, 2)<br/>  }))</pre> | n/a | yes |
| default\_target\_group | Which target group receives traffic that matches no listener rule. Ignored when default\_fixed\_response is set. | `string` | `null` | no |
| default\_fixed\_response | Answer traffic that matches no listener rule with a fixed response instead of forwarding it. With an http\_headers rule, this refuses any request not carrying a shared origin header. | <pre>object({<br/>    status_code  = optional(number, 403)<br/>    content_type = optional(string, "text/plain")<br/>    message_body = optional(string)<br/>  })</pre> | `null` | no |
| listener\_rules | Rules on the HTTPS listener, keyed by a stable name. Lower priority numbers are evaluated first. Each needs at least one of host\_headers, path\_patterns or http\_headers. | <pre>map(object({<br/>    priority      = number<br/>    target_group  = string<br/>    host_headers  = optional(list(string))<br/>    path_patterns = optional(list(string))<br/>    http_headers  = optional(map(list(string)))<br/>  }))</pre> | `{}` | no |
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
| https\_listener\_arn | ARN of the HTTPS listener, or null when create\_https\_listener is off. |
| http\_listener\_arn | ARN of the HTTP listener, or null when create\_http\_listener is off. |
| https\_listener\_default\_action | What the HTTPS listener does with a request no rule matches: type is forward or fixed-response, and status\_code is the fixed response's status, else null. Null when create\_https\_listener is off. |
| listener\_rules | Listener rules keyed by name: priority, action type, target group key, and the host, path and header names each rule matches on. Header values are left out because they are often a shared secret. |
<!-- END_TF_DOCS -->
