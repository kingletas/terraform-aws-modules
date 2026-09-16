variable "name" {
  type        = string
  description = "Name prefix for the security group."
}

variable "description" {
  type        = string
  description = "What this security group is for. AWS will not let you change it later without replacing the group."
}

variable "vpc_id" {
  type        = string
  description = "VPC the security group belongs to."
}

variable "ingress_rules" {
  type = map(object({
    description                  = string
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
    self                         = optional(bool, false)
  }))
  description = "Inbound rules keyed by a stable name. Give each rule exactly one source: a CIDR, another security group, a prefix list, or self."
  default     = {}

  validation {
    condition = alltrue([
      for name, rule in var.ingress_rules : length(compact([
        rule.cidr_ipv4,
        rule.cidr_ipv6,
        rule.referenced_security_group_id,
        rule.prefix_list_id,
        rule.self ? "self" : null,
      ])) == 1
    ])
    error_message = "Each ingress rule needs exactly one source: cidr_ipv4, cidr_ipv6, referenced_security_group_id, prefix_list_id or self."
  }

  validation {
    condition     = alltrue([for name, rule in var.ingress_rules : trimspace(rule.description) != ""])
    error_message = "Every ingress rule needs a non-empty description."
  }

  validation {
    condition = alltrue([
      for name, rule in var.ingress_rules : try(
        contains(["-1", "tcp", "udp", "icmp", "icmpv6"], lower(rule.ip_protocol)) || (can(regex("^[0-9]{1,3}$", rule.ip_protocol)) && tonumber(rule.ip_protocol) <= 255),
        false
      )
    ])
    error_message = "Each ingress rule's ip_protocol must be -1 for all traffic, tcp, udp, icmp, icmpv6, or a protocol number from 0 to 255."
  }

  validation {
    condition = alltrue([
      for name, rule in var.ingress_rules : try(
        !contains(["tcp", "udp", "6", "17"], lower(rule.ip_protocol)) || (rule.from_port >= 0 && rule.to_port <= 65535 && rule.from_port <= rule.to_port),
        false
      )
    ])
    error_message = "Each tcp or udp ingress rule needs from_port and to_port between 0 and 65535, with from_port no greater than to_port."
  }

  validation {
    condition = alltrue([
      for name, rule in var.ingress_rules : try(
        !contains(["icmp", "icmpv6", "1", "58"], lower(rule.ip_protocol)) || (
          (rule.from_port == null || (rule.from_port >= -1 && rule.from_port <= 255)) &&
          (rule.to_port == null || (rule.to_port >= -1 && rule.to_port <= 255))
        ),
        false
      )
    ])
    error_message = "An icmp or icmpv6 ingress rule's from_port (type) and to_port (code) must be between -1 and 255."
  }
}

variable "egress_rules" {
  type = map(object({
    description                  = string
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
    self                         = optional(bool, false)
  }))
  description = "Outbound rules keyed by a stable name. Give each rule exactly one destination: a CIDR, another security group, a prefix list, or self. Leave empty to allow all outbound IPv4 traffic."
  default     = {}

  validation {
    condition = alltrue([
      for name, rule in var.egress_rules : length(compact([
        rule.cidr_ipv4,
        rule.cidr_ipv6,
        rule.referenced_security_group_id,
        rule.prefix_list_id,
        rule.self ? "self" : null,
      ])) == 1
    ])
    error_message = "Each egress rule needs exactly one destination: cidr_ipv4, cidr_ipv6, referenced_security_group_id, prefix_list_id or self."
  }

  validation {
    condition     = alltrue([for name, rule in var.egress_rules : trimspace(rule.description) != ""])
    error_message = "Every egress rule needs a non-empty description."
  }

  validation {
    condition = alltrue([
      for name, rule in var.egress_rules : try(
        contains(["-1", "tcp", "udp", "icmp", "icmpv6"], lower(rule.ip_protocol)) || (can(regex("^[0-9]{1,3}$", rule.ip_protocol)) && tonumber(rule.ip_protocol) <= 255),
        false
      )
    ])
    error_message = "Each egress rule's ip_protocol must be -1 for all traffic, tcp, udp, icmp, icmpv6, or a protocol number from 0 to 255."
  }

  validation {
    condition = alltrue([
      for name, rule in var.egress_rules : try(
        !contains(["tcp", "udp", "6", "17"], lower(rule.ip_protocol)) || (rule.from_port >= 0 && rule.to_port <= 65535 && rule.from_port <= rule.to_port),
        false
      )
    ])
    error_message = "Each tcp or udp egress rule needs from_port and to_port between 0 and 65535, with from_port no greater than to_port."
  }

  validation {
    condition = alltrue([
      for name, rule in var.egress_rules : try(
        !contains(["icmp", "icmpv6", "1", "58"], lower(rule.ip_protocol)) || (
          (rule.from_port == null || (rule.from_port >= -1 && rule.from_port <= 255)) &&
          (rule.to_port == null || (rule.to_port >= -1 && rule.to_port <= 255))
        ),
        false
      )
    ])
    error_message = "An icmp or icmpv6 egress rule's from_port (type) and to_port (code) must be between -1 and 255."
  }
}

variable "allow_all_egress" {
  type        = bool
  description = "Add a rule permitting all outbound IPv4 traffic. Ignored when egress_rules is non-empty."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the security group."
  default     = {}
}
