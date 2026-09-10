variable "name" {
  type        = string
  description = "Web ACL name."
}

variable "description" {
  type        = string
  description = "What this web ACL protects."
  default     = null
}

variable "scope" {
  type        = string
  description = "REGIONAL for a load balancer or API Gateway. CLOUDFRONT must be created in us-east-1."
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "The scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  type        = string
  description = "What happens to a request no rule matched: allow or block."
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "The default_action must be allow or block."
  }
}

variable "managed_rule_groups" {
  type = map(object({
    priority       = number
    vendor_name    = optional(string, "AWS")
    count_only     = optional(bool, false)
    excluded_rules = optional(list(string), [])
  }))
  description = "AWS managed rule groups keyed by group name. Start with count_only, read the metrics, then enforce."
  default = {
    AWSManagedRulesCommonRuleSet          = { priority = 10 }
    AWSManagedRulesKnownBadInputsRuleSet  = { priority = 20 }
    AWSManagedRulesAmazonIpReputationList = { priority = 30 }
  }
}

variable "rate_limits" {
  type = map(object({
    priority              = number
    limit                 = number
    aggregate_key_type    = optional(string, "IP")
    action                = optional(string, "block")
    scope_down_uri_prefix = optional(string)
  }))
  description = "Rate-based rules keyed by a stable name. The limit is requests per five minutes from one key."
  default     = {}
}

variable "ip_allow_lists" {
  type = map(object({
    priority = number
    arn      = string
  }))
  description = "IP sets that are always allowed, keyed by a stable name. Give these low priority numbers so they run first."
  default     = {}
}

variable "ip_block_lists" {
  type = map(object({
    priority = number
    arn      = string
  }))
  description = "IP sets that are always blocked, keyed by a stable name."
  default     = {}
}

variable "log_destination_arns" {
  type        = list(string)
  description = "Where to send request logs: a CloudWatch log group whose name starts aws-waf-logs-, a Firehose, or an S3 bucket."
  default     = []
}

variable "redacted_header_names" {
  type        = list(string)
  description = "Headers to redact from logs. Authorization and cookie are the ones that matter."
  default     = ["authorization", "cookie"]
}

variable "associations" {
  type        = map(string)
  description = "Load balancer or API Gateway stage ARNs to attach the web ACL to, keyed by a stable name. The keys must be known at plan; the ARNs need not be. CloudFront is attached from the distribution instead."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the web ACL."
  default     = {}
}
