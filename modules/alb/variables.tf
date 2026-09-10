variable "name" {
  type        = string
  description = "Name for the load balancer. AWS caps this at 32 characters."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,30}[a-zA-Z0-9]$", var.name))
    error_message = "The name must be 2-32 alphanumeric characters or hyphens, and may not start or end with a hyphen."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC the target groups belong to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets to place the load balancer in. Public subnets for an internet-facing one, at least two zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "An application load balancer needs subnets in at least two availability zones."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups on the load balancer."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Make the load balancer reachable only from inside the VPC."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate for the HTTPS listener. Null creates an HTTP listener only, which you should not do in production."
  default     = null
}

variable "additional_certificate_arns" {
  type        = list(string)
  description = "Extra certificates on the HTTPS listener, for serving several host names."
  default     = []
}

variable "ssl_policy" {
  type        = string
  description = "TLS policy. The TLS13 policies are current; the older ones exist for clients that cannot negotiate it."
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "redirect_http_to_https" {
  type        = bool
  description = "Answer plain HTTP with a permanent redirect to HTTPS. Ignored without a certificate."
  default     = true
}

variable "target_groups" {
  type = map(object({
    port                 = number
    protocol             = optional(string, "HTTP")
    protocol_version     = optional(string, "HTTP1")
    target_type          = optional(string, "instance")
    deregistration_delay = optional(number, 30)
    slow_start           = optional(number, 0)
    stickiness_enabled   = optional(bool, false)
    stickiness_duration  = optional(number, 86400)

    health_check_path                = optional(string, "/")
    health_check_matcher             = optional(string, "200")
    health_check_interval            = optional(number, 30)
    health_check_timeout             = optional(number, 5)
    health_check_healthy_threshold   = optional(number, 2)
    health_check_unhealthy_threshold = optional(number, 2)
  }))
  description = "Target groups keyed by a stable name. One of them must be named as the default_target_group."

  validation {
    condition     = length(var.target_groups) > 0
    error_message = "At least one target group is required."
  }
}

variable "default_target_group" {
  type        = string
  description = "Which target group receives traffic that matches no listener rule."
}

variable "listener_rules" {
  type = map(object({
    priority      = number
    target_group  = string
    host_headers  = optional(list(string))
    path_patterns = optional(list(string))
    http_headers  = optional(map(list(string)))
  }))
  description = "Rules on the HTTPS listener, keyed by a stable name. Lower priority numbers are evaluated first."
  default     = {}
}

variable "access_logs" {
  type = object({
    bucket  = string
    prefix  = optional(string)
    enabled = optional(bool, true)
  })
  description = "S3 bucket for access logs. The bucket policy must already allow the load balancing service to write."
  default     = null
}

variable "idle_timeout" {
  type        = number
  description = "Seconds a connection may sit idle. Raise it above your slowest backend response or the client sees a 504."
  default     = 60
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Refuse to delete the load balancer until this is turned off."
  default     = true
}

variable "drop_invalid_header_fields" {
  type        = bool
  description = "Drop malformed headers instead of forwarding them, which closes a class of request smuggling."
  default     = true
}

variable "enable_http2" {
  type        = bool
  description = "Serve HTTP/2 to clients that ask for it."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
