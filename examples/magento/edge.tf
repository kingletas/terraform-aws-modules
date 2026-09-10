module "certificate" {
  source = "../../modules/acm-certificate"

  providers = { aws = aws.us_east_1 }

  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.this.zone_id

  tags = local.tags
}

# A regional certificate for the load balancer, because CloudFront's must be in
# us-east-1 and the two cannot be shared.
module "origin_certificate" {
  source = "../../modules/acm-certificate"

  domain_name = format("origin.%s", var.domain_name)
  zone_id     = data.aws_route53_zone.this.zone_id

  tags = local.tags
}

module "alb" {
  source = "../../modules/alb"

  name       = module.context.short_prefix
  vpc_id     = module.vpc.vpc_id
  subnet_ids = values(module.vpc.public_subnet_ids)

  security_group_ids = [module.alb_sg.id]
  certificate_arn    = module.origin_certificate.validated_arn

  target_groups = {
    web = {
      port              = 80
      health_check_path = "/health_check.php"

      # Slow during a config flush. A shorter timeout takes the whole fleet out
      # of rotation and returns 503s that say nothing about caches.
      health_check_timeout  = 10
      health_check_interval = 30

      # Checkout is a POST.
      deregistration_delay = 120
    }
  }

  default_target_group = "web"
  idle_timeout         = 120

  enable_deletion_protection = local.defaults.deletion_protection

  access_logs = {
    bucket = module.cdn_logs.id
    prefix = "alb"
  }

  tags = local.tags
}

resource "aws_route53_record" "origin" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = format("origin.%s", var.domain_name)
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

# --- the edge ---

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../../modules/waf-web-acl"

  providers = { aws = aws.us_east_1 }

  name  = local.prefix
  scope = "CLOUDFRONT"

  managed_rule_groups = {
    # Count first. The common rule set has real false positives against
    # Magento's admin, which posts large serialised payloads.
    AWSManagedRulesCommonRuleSet          = { priority = 10, count_only = true }
    AWSManagedRulesKnownBadInputsRuleSet  = { priority = 20 }
    AWSManagedRulesAmazonIpReputationList = { priority = 30 }
    AWSManagedRulesSQLiRuleSet            = { priority = 40 }
  }

  rate_limits = {
    admin = {
      priority              = 5
      limit                 = 100
      scope_down_uri_prefix = "/admin"
    }
    storefront = {
      priority = 50
      limit    = 3000
    }
  }


  tags = local.tags
}

# CloudFront rather than a Varnish tier. It caches at the edge instead of in one
# region, needs no instances to patch, and Magento's own full page cache in
# Redis already covers what Varnish was doing behind the load balancer.
module "cdn" {
  source = "../../modules/cloudfront-distribution"

  comment         = format("%s storefront", local.prefix)
  aliases         = [var.domain_name]
  certificate_arn = module.certificate.validated_arn
  price_class     = module.context.is_production ? "PriceClass_200" : "PriceClass_100"
  web_acl_arn     = var.enable_waf ? module.waf[0].arn : null

  origins = {
    origin = {
      domain_name     = aws_route53_record.origin.fqdn
      custom_protocol = "https-only"

      # A shared secret the load balancer can require, so nobody reaches the
      # origin directly and bypasses the WAF.
      custom_headers = {
        "X-Origin-Verify" = random_password.origin_verify.result
      }
    }

    static = {
      domain_name                  = module.static_assets.regional_domain_name
      create_origin_access_control = true
    }
  }

  default_origin = "origin"

  default_behaviour = {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    compress               = true

    # AllViewer, because Magento routes on host, cookies and query string.
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  ordered_behaviours = {
    static = {
      path_pattern    = "/static/*"
      origin          = "static"
      precedence      = 10
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    }
    media = {
      path_pattern    = "/media/*"
      origin          = "origin"
      precedence      = 20
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    }
  }

  logging = {
    bucket = format("%s.s3.amazonaws.com", module.cdn_logs.id)
    prefix = "cloudfront/"
  }

  tags = local.tags
}

resource "random_password" "origin_verify" {
  length  = 48
  special = false
}

resource "aws_route53_record" "storefront" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.cdn.domain_name
    zone_id                = module.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# Only this distribution may read the static bucket.
data "aws_iam_policy_document" "static" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [format("%s/*", module.static_assets.arn)]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = module.static_assets.id
  policy = data.aws_iam_policy_document.static.json
}
