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
  description = "Subnets to place the load balancer in."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups on the load balancer. A network load balancer created without any can never have one added."
  default     = []
}

variable "internal" {
  type        = bool
  description = "Make the load balancer reachable only from inside the VPC."
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  description = "Spread traffic across zones evenly. Off by default in AWS, and cross-zone data transfer is billed."
  default     = true
}

variable "listeners" {
  type = map(object({
    port            = number
    protocol        = optional(string, "TCP")
    target_group    = string
    certificate_arn = optional(string)
    ssl_policy      = optional(string, "ELBSecurityPolicy-TLS13-1-2-2021-06")
  }))
  description = "Listeners keyed by a stable name. TLS listeners need a certificate_arn."

  validation {
    condition = alltrue([
      for name, listener in var.listeners :
      listener.protocol != "TLS" || listener.certificate_arn != null
    ])
    error_message = "A TLS listener needs a certificate_arn."
  }
}

variable "target_groups" {
  type = map(object({
    port                 = number
    protocol             = optional(string, "TCP")
    target_type          = optional(string, "instance")
    deregistration_delay = optional(number, 30)
    preserve_client_ip   = optional(bool)
    proxy_protocol_v2    = optional(bool, false)

    health_check_protocol            = optional(string, "TCP")
    health_check_port                = optional(string, "traffic-port")
    health_check_path                = optional(string)
    health_check_interval            = optional(number, 30)
    health_check_healthy_threshold   = optional(number, 3)
    health_check_unhealthy_threshold = optional(number, 3)
  }))
  description = "Target groups keyed by a stable name."

  validation {
    condition     = length(var.target_groups) > 0
    error_message = "At least one target group is required."
  }
}

variable "access_logs" {
  type = object({
    bucket  = string
    prefix  = optional(string)
    enabled = optional(bool, true)
  })
  description = "S3 bucket for access logs. Only recorded for TLS listeners."
  default     = null
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Refuse to delete the load balancer until this is turned off."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
