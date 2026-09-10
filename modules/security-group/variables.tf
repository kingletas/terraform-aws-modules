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
  description = "Outbound rules keyed by a stable name. Leave empty to allow all outbound IPv4 traffic."
  default     = {}
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
