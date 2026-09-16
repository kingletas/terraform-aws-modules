# cloudfront-distribution

A CloudFront distribution with origin access control for S3, ordered cache behaviours and HTTPS enforced.

## Usage

```hcl
module "cdn" {
  source = "github.com/kingletas/terraform-aws-modules//modules/cloudfront-distribution?ref=v0.3.0"

  comment         = "platform web"
  aliases         = ["www.example.com"]
  certificate_arn = module.certificate_us_east_1.validated_arn

  origins = {
    static = {
      domain_name                  = module.assets.regional_domain_name
      create_origin_access_control = true
    }
    api = {
      domain_name = "origin.example.com" # a name the load balancer's certificate covers
    }
  }

  default_origin = "static"

  ordered_behaviours = {
    api = {
      path_pattern    = "/api/*"
      origin          = "api"
      precedence      = 10
      allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    }
  }
}
```

## Origin access control, and the policy this module does not write

`create_origin_access_control` makes the signing identity, but **the bucket policy that trusts it is the caller's to write**, so that the bucket's policy stays defined in one place. With the `s3-bucket` module, pass it in `policy_documents`.

Grant `s3:GetObject` to the `cloudfront.amazonaws.com` service principal, conditioned on `AWS:SourceArn` equal to this distribution's `arn`. Without it, every request returns 403 and the distribution looks broken rather than unauthorised.

## Notes

- **The certificate must be in us-east-1**, whatever region you deploy from. Use an aliased provider.
- Use the bucket's **regional** domain name, not its global one, or the first requests redirect and cache oddly.
- A change takes several minutes to reach every edge location. `status` says whether it has finished.
- `PriceClass_100` is North America and Europe only and is materially cheaper.
- Ordered behaviours are sent to CloudFront lowest `precedence` first, and CloudFront uses the first path pattern that matches. `precedence` is a whole number from 0 to 999999999, and equal values fall back to the order of the behaviour names.
- A behaviour with no `cache_policy_id`, the default one included, uses the AWS managed `Managed-CachingOptimized` policy. That caches responses, so set a different policy (such as `Managed-CachingDisabled`) for a dynamic origin like an API.
- A custom origin defaults to `https-only`, so its certificate must cover the origin `domain_name`. A load balancer's generated DNS name cannot be covered by a certificate you own; point the origin at a DNS name of your own instead.
- Access logging needs a bucket with ACLs enabled, which conflicts with the `s3-bucket` module's default `BucketOwnerEnforced`.

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
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| comment | What this distribution serves. CloudFront has no name field, so this is how you tell them apart. | `string` | n/a | yes |
| aliases | Domain names the distribution answers on. Each needs to be covered by the certificate. | `list(string)` | `[]` | no |
| certificate\_arn | ACM certificate, which must be in us-east-1 whatever region you deploy from. Null uses the CloudFront default certificate and no aliases. | `string` | `null` | no |
| origins | Origins keyed by a stable ID. An S3 bucket uses origin access control; anything else is treated as a custom origin. | <pre>map(object({<br/>    domain_name = string<br/>    origin_path = optional(string)<br/><br/>    s3_origin_access_control_id  = optional(string)<br/>    create_origin_access_control = optional(bool, false)<br/><br/>    custom_http_port     = optional(number, 80)<br/>    custom_https_port    = optional(number, 443)<br/>    custom_protocol      = optional(string, "https-only")<br/>    custom_ssl_protocols = optional(list(string), ["TLSv1.2"])<br/><br/>    custom_headers = optional(map(string), {})<br/><br/>    connection_attempts = optional(number, 3)<br/>    connection_timeout  = optional(number, 10)<br/>  }))</pre> | n/a | yes |
| default\_origin | Origin serving anything no ordered behaviour matched. | `string` | n/a | yes |
| default\_behaviour | Cache behaviour for everything not matched by an ordered behaviour. A null cache\_policy\_id uses Managed-CachingOptimized. | <pre>object({<br/>    viewer_protocol_policy = optional(string, "redirect-to-https")<br/>    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])<br/>    cached_methods         = optional(list(string), ["GET", "HEAD"])<br/>    compress               = optional(bool, true)<br/><br/>    cache_policy_id            = optional(string)<br/>    origin_request_policy_id   = optional(string)<br/>    response_headers_policy_id = optional(string)<br/><br/>    function_associations = optional(map(object({<br/>      event_type   = string<br/>      function_arn = string<br/>    })), {})<br/>  })</pre> | `{}` | no |
| ordered\_behaviours | Path-specific behaviours keyed by a stable name. Lower precedence numbers are evaluated first, and equal precedences fall back to name order. A null cache\_policy\_id uses Managed-CachingOptimized. | <pre>map(object({<br/>    path_pattern           = string<br/>    origin                 = string<br/>    precedence             = number<br/>    viewer_protocol_policy = optional(string, "redirect-to-https")<br/>    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])<br/>    cached_methods         = optional(list(string), ["GET", "HEAD"])<br/>    compress               = optional(bool, true)<br/><br/>    cache_policy_id            = optional(string)<br/>    origin_request_policy_id   = optional(string)<br/>    response_headers_policy_id = optional(string)<br/>  }))</pre> | `{}` | no |
| price\_class | Which edge locations serve traffic. PriceClass\_100 is North America and Europe only and is much cheaper. | `string` | `"PriceClass_100"` | no |
| web\_acl\_arn | WAF web ACL, which must have been created with CLOUDFRONT scope in us-east-1. | `string` | `null` | no |
| default\_root\_object | Object served for a request to the root path. | `string` | `"index.html"` | no |
| custom\_error\_responses | Custom error responses keyed by a stable name. A single-page app maps 403 and 404 to /index.html with a 200. | <pre>map(object({<br/>    error_code            = number<br/>    response_code         = optional(number)<br/>    response_page_path    = optional(string)<br/>    error_caching_min_ttl = optional(number, 10)<br/>  }))</pre> | `{}` | no |
| geo\_restriction | Geographic restriction: whitelist or blacklist with two-letter country codes. Null allows everywhere. | <pre>object({<br/>    type      = string<br/>    locations = list(string)<br/>  })</pre> | `null` | no |
| logging | S3 bucket for access logs. The bucket needs ACLs enabled, which conflicts with BucketOwnerEnforced. | <pre>object({<br/>    bucket          = string<br/>    prefix          = optional(string)<br/>    include_cookies = optional(bool, false)<br/>  })</pre> | `null` | no |
| http\_version | Highest HTTP version offered to viewers. | `string` | `"http2and3"` | no |
| ipv6\_enabled | Answer over IPv6 as well as IPv4. | `bool` | `true` | no |
| tags | Tags applied to the distribution. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the distribution, which an invalidation command needs. |
| arn | ARN of the distribution. An S3 bucket policy uses this to allow only this distribution. |
| domain\_name | CloudFront domain name. Point an alias record at this. |
| hosted\_zone\_id | Hosted zone ID for a Route 53 alias record. The same for every CloudFront distribution. |
| status | Deployment status. A change takes several minutes to reach every edge location. |
| origin\_access\_control\_ids | Origin access control IDs created here, keyed by origin ID. |
<!-- END_TF_DOCS -->
