data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

locals {
  prefix = format("%s-%s", var.name, var.environment)

  # The content policy names its bucket by ARN, which cannot come from the module that waits for that policy.
  content_bucket = format("%s-content-%s", local.prefix, data.aws_caller_identity.current.account_id)
  all_domains    = concat([var.domain_name], var.additional_domains)

  tags = {
    Environment = var.environment
    Site        = var.name
    ManagedBy   = "terraform"
  }
}

# --- content ---

module "content" {
  source = "../../modules/s3-bucket"

  name = local.content_bucket

  # No customer key. CloudFront reads objects through origin access control,
  # and a customer-managed key means adding CloudFront to the key policy too.
  versioning_enabled = true

  policy_documents = [data.aws_iam_policy_document.content.json]

  lifecycle_rules = {
    expire_old_deploys = {
      noncurrent_version_expiration_days = 30
    }
  }

  tags = local.tags
}

# CloudFront access logging needs a bucket with ACLs enabled, which is exactly
# what the content bucket's BucketOwnerEnforced setting forbids. Hence a second.
module "logs" {
  source = "../../modules/s3-bucket"

  name             = format("%s-logs-%s", local.prefix, data.aws_caller_identity.current.account_id)
  object_ownership = "BucketOwnerPreferred"

  lifecycle_rules = {
    expire = {
      expiration_days = 90
    }
  }

  tags = local.tags
}

# --- certificate, in us-east-1 because CloudFront insists ---

module "certificate" {
  source = "../../modules/acm-certificate"

  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.domain_name
  subject_alternative_names = var.additional_domains
  zone_id                   = data.aws_route53_zone.this.zone_id

  tags = local.tags
}

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../../modules/waf-web-acl"

  providers = {
    aws = aws.us_east_1
  }

  name  = local.prefix
  scope = "CLOUDFRONT"

  managed_rule_groups = {
    AWSManagedRulesCommonRuleSet          = { priority = 10 }
    AWSManagedRulesKnownBadInputsRuleSet  = { priority = 20 }
    AWSManagedRulesAmazonIpReputationList = { priority = 30 }
  }

  rate_limits = {
    all = {
      priority = 50
      limit    = 10000
    }
  }


  tags = local.tags
}

# --- distribution ---

module "cdn" {
  source = "../../modules/cloudfront-distribution"

  comment         = format("%s static site", local.prefix)
  aliases         = local.all_domains
  certificate_arn = module.certificate.validated_arn
  price_class     = var.price_class
  web_acl_arn     = var.enable_waf ? module.waf[0].arn : null
  geo_restriction = var.geo_restriction

  origins = {
    content = {
      domain_name                  = module.content.regional_domain_name
      create_origin_access_control = true
    }
  }

  default_origin = "content"

  default_behaviour = {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # AWS managed policies, so this example does not reinvent caching rules.
    # CachingOptimized, and CORS-S3Origin for the request policy.
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  custom_error_responses = var.single_page_app ? {
    forbidden = {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    }
    not_found = {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    }
  } : {}

  logging = {
    bucket = format("%s.s3.amazonaws.com", module.logs.id)
    prefix = "cloudfront/"
  }

  tags = local.tags
}

# --- the grant merged into the content bucket's policy ---

# Only this distribution may read the bucket. Without it every request is a 403
# and the site looks broken rather than unauthorised.
data "aws_iam_policy_document" "content" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [format("arn:%s:s3:::%s/*", data.aws_partition.current.partition, local.content_bucket)]

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

# --- names ---

resource "aws_route53_record" "site" {
  for_each = toset(local.all_domains)

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = module.cdn.domain_name
    zone_id                = module.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
