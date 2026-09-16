locals {
  # Zero-padded precedence then name, so a lexical sort is numeric order with a stable tie-break.
  behaviours_by_sort_key = {
    for name, behaviour in var.ordered_behaviours : format("%010d/%s", behaviour.precedence, name) => behaviour
  }

  ordered_behaviours = [for sort_key in sort(keys(local.behaviours_by_sort_key)) : local.behaviours_by_sort_key[sort_key]]

  oac_origins = { for id, origin in var.origins : id => origin if origin.create_origin_access_control }

  # An S3 REST endpoint is served through origin access control; everything else is a custom origin.
  s3_origins = {
    for id, origin in var.origins : id => origin
    if origin.create_origin_access_control || origin.s3_origin_access_control_id != null
  }
}

# The fallback cache policy, looked up by name so it resolves in every partition.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "this" {
  for_each = local.oac_origins

  name                              = format("%s-%s", replace(var.comment, " ", "-"), each.key)
  description                       = format("Access control for %s", each.key)
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  # checkov:skip=CKV_AWS_310: origin groups are not implemented in this module yet
  enabled             = true
  comment             = var.comment
  aliases             = var.aliases
  price_class         = var.price_class
  default_root_object = var.default_root_object
  web_acl_id          = var.web_acl_arn
  http_version        = var.http_version
  is_ipv6_enabled     = var.ipv6_enabled

  dynamic "origin" {
    for_each = var.origins

    content {
      origin_id           = origin.key
      domain_name         = origin.value.domain_name
      origin_path         = origin.value.origin_path
      connection_attempts = origin.value.connection_attempts
      connection_timeout  = origin.value.connection_timeout

      origin_access_control_id = (
        origin.value.create_origin_access_control
        ? aws_cloudfront_origin_access_control.this[origin.key].id
        : origin.value.s3_origin_access_control_id
      )

      dynamic "custom_origin_config" {
        for_each = contains(keys(local.s3_origins), origin.key) ? [] : [origin.value]

        content {
          http_port                = custom_origin_config.value.custom_http_port
          https_port               = custom_origin_config.value.custom_https_port
          origin_protocol_policy   = custom_origin_config.value.custom_protocol
          origin_ssl_protocols     = custom_origin_config.value.custom_ssl_protocols
          origin_keepalive_timeout = 5
          origin_read_timeout      = 30
        }
      }

      dynamic "custom_header" {
        for_each = origin.value.custom_headers

        content {
          name  = custom_header.key
          value = custom_header.value
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = var.default_origin
    viewer_protocol_policy = var.default_behaviour.viewer_protocol_policy
    allowed_methods        = var.default_behaviour.allowed_methods
    cached_methods         = var.default_behaviour.cached_methods
    compress               = var.default_behaviour.compress

    cache_policy_id            = var.default_behaviour.cache_policy_id != null ? var.default_behaviour.cache_policy_id : data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id   = var.default_behaviour.origin_request_policy_id
    response_headers_policy_id = var.default_behaviour.response_headers_policy_id

    dynamic "function_association" {
      for_each = var.default_behaviour.function_associations

      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.ordered_behaviours

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.origin
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      compress               = ordered_cache_behavior.value.compress

      cache_policy_id            = ordered_cache_behavior.value.cache_policy_id != null ? ordered_cache_behavior.value.cache_policy_id : data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id   = ordered_cache_behavior.value.origin_request_policy_id
      response_headers_policy_id = ordered_cache_behavior.value.response_headers_policy_id
    }
  }

  dynamic "custom_error_response" {
    for_each = var.custom_error_responses

    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction == null ? "none" : var.geo_restriction.type
      locations        = var.geo_restriction == null ? [] : var.geo_restriction.locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == null
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = var.certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.certificate_arn == null ? null : "TLSv1.2_2021"
  }

  dynamic "logging_config" {
    for_each = var.logging == null ? [] : [var.logging]

    content {
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
      include_cookies = logging_config.value.include_cookies
    }
  }

  tags = merge(var.tags, { Name = var.comment })

  lifecycle {
    precondition {
      condition     = contains(keys(var.origins), var.default_origin)
      error_message = "The default_origin must name one of the origins."
    }

    precondition {
      condition     = length(var.aliases) == 0 || var.certificate_arn != null
      error_message = "Aliases need a certificate_arn, and the certificate must be in us-east-1."
    }
  }
}
