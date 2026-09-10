variable "name" {
  type        = string
  description = "Domain name for the zone, such as example.com."
}

variable "comment" {
  type        = string
  description = "What this zone is for."
  default     = null
}

variable "private_vpc_ids" {
  type        = list(string)
  description = "VPCs the zone answers inside. Empty makes the zone public."
  default     = []
}

variable "force_destroy" {
  type        = bool
  description = "Let terraform destroy delete a zone that still holds records it did not create."
  default     = false
}

variable "records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = optional(number, 300)
    records = optional(list(string), [])

    alias_name                   = optional(string)
    alias_zone_id                = optional(string)
    alias_evaluate_target_health = optional(bool, true)

    set_identifier  = optional(string)
    weight          = optional(number)
    failover        = optional(string)
    health_check_id = optional(string)
  }))
  description = "Records keyed by a stable name. An alias points at an AWS resource and is free to resolve; a CNAME is billed per query and cannot sit at the apex."
  default     = {}

  validation {
    condition = alltrue([
      for key, record in var.records :
      length(record.records) > 0 != (record.alias_name != null)
    ])
    error_message = "Each record needs either records or an alias_name, and not both."
  }
}

variable "health_checks" {
  type = map(object({
    fqdn              = optional(string)
    ip_address        = optional(string)
    port              = optional(number, 443)
    type              = optional(string, "HTTPS")
    resource_path     = optional(string, "/")
    failure_threshold = optional(number, 3)
    request_interval  = optional(number, 30)
    regions           = optional(list(string))
  }))
  description = "Health checks keyed by a stable name, for failover records."
  default     = {}
}

variable "enable_query_logging" {
  type        = bool
  description = "Log every query against a public zone. The log group must be in us-east-1 and named /aws/route53/<zone>."
  default     = false
}

variable "query_log_group_arn" {
  type        = string
  description = "CloudWatch log group for query logs. Required when enable_query_logging is on."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the zone and its health checks."
  default     = {}
}
