variable "comment" {
  type        = string
  description = "What this distribution serves. CloudFront has no name field, so this is how you tell them apart."
}

variable "aliases" {
  type        = list(string)
  description = "Domain names the distribution answers on. Each needs to be covered by the certificate."
  default     = []
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate, which must be in us-east-1 whatever region you deploy from. Null uses the CloudFront default certificate and no aliases."
  default     = null
}

variable "origins" {
  type = map(object({
    domain_name = string
    origin_path = optional(string)

    s3_origin_access_control_id  = optional(string)
    create_origin_access_control = optional(bool, false)

    custom_http_port     = optional(number, 80)
    custom_https_port    = optional(number, 443)
    custom_protocol      = optional(string, "https-only")
    custom_ssl_protocols = optional(list(string), ["TLSv1.2"])

    custom_headers = optional(map(string), {})

    connection_attempts = optional(number, 3)
    connection_timeout  = optional(number, 10)
  }))
  description = "Origins keyed by a stable ID. An S3 bucket uses origin access control; anything else is treated as a custom origin."

  validation {
    condition     = length(var.origins) > 0
    error_message = "At least one origin is required."
  }
}

variable "default_origin" {
  type        = string
  description = "Origin serving anything no ordered behaviour matched."
}

variable "default_behaviour" {
  type = object({
    viewer_protocol_policy = optional(string, "redirect-to-https")
    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    compress               = optional(bool, true)

    cache_policy_id            = optional(string)
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)

    function_associations = optional(map(object({
      event_type   = string
      function_arn = string
    })), {})
  })
  description = "Cache behaviour for everything not matched by an ordered behaviour. cache_policy_id is required."
  default     = {}

  validation {
    condition     = var.default_behaviour.cache_policy_id != null
    error_message = "The default behaviour needs a cache_policy_id: Managed-CachingOptimized for a static origin, or Managed-CachingDisabled with an origin request policy for an application."
  }
}

variable "ordered_behaviours" {
  type = map(object({
    path_pattern           = string
    origin                 = string
    precedence             = number
    viewer_protocol_policy = optional(string, "redirect-to-https")
    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    compress               = optional(bool, true)

    cache_policy_id            = optional(string)
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = optional(string)
  }))
  description = "Path-specific behaviours keyed by a stable name. Lower precedence numbers are evaluated first, and equal precedences fall back to name order. Each needs a cache_policy_id."
  default     = {}

  validation {
    condition     = alltrue([for behaviour in values(var.ordered_behaviours) : behaviour.cache_policy_id != null])
    error_message = "Every ordered behaviour needs a cache_policy_id: Managed-CachingOptimized for static content, or Managed-CachingDisabled with an origin request policy for an application."
  }

  validation {
    condition = alltrue([
      for behaviour in values(var.ordered_behaviours) :
      behaviour.precedence >= 0 && behaviour.precedence < 1000000000 && floor(behaviour.precedence) == behaviour.precedence
    ])
    error_message = "Each precedence must be a whole number from 0 to 999999999."
  }
}

variable "price_class" {
  type        = string
  description = "Which edge locations serve traffic. PriceClass_100 is North America and Europe only and is much cheaper."
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "The price_class must be PriceClass_All, PriceClass_200 or PriceClass_100."
  }
}

variable "web_acl_arn" {
  type        = string
  description = "WAF web ACL, which must have been created with CLOUDFRONT scope in us-east-1."
  default     = null
}

variable "default_root_object" {
  type        = string
  description = "Object served for a request to the root path."
  default     = "index.html"
}

variable "custom_error_responses" {
  type = map(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number, 10)
  }))
  description = "Custom error responses keyed by a stable name. A single-page app maps 403 and 404 to /index.html with a 200."
  default     = {}
}

variable "geo_restriction" {
  type = object({
    type      = string
    locations = list(string)
  })
  description = "Geographic restriction: whitelist or blacklist with two-letter country codes. Null allows everywhere."
  default     = null
}

variable "logging" {
  type = object({
    bucket          = string
    prefix          = optional(string)
    include_cookies = optional(bool, false)
  })
  description = "S3 bucket for access logs. The bucket needs ACLs enabled, which conflicts with BucketOwnerEnforced."
  default     = null
}

variable "http_version" {
  type        = string
  description = "Highest HTTP version offered to viewers."
  default     = "http2and3"
}

variable "ipv6_enabled" {
  type        = bool
  description = "Answer over IPv6 as well as IPv4."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the distribution."
  default     = {}
}
