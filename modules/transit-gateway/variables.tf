variable "name" {
  type        = string
  description = "Name for the transit gateway."
}

variable "description" {
  type        = string
  description = "What this gateway connects."
  default     = null
}

variable "amazon_side_asn" {
  type        = number
  description = "BGP ASN on the AWS side. Cannot be changed after creation."
  default     = 64512
}

variable "auto_accept_shared_attachments" {
  type        = bool
  description = "Accept attachments from other accounts without review. Off, so somebody has to approve each one."
  default     = false
}

variable "default_route_table_association" {
  type        = bool
  description = "Attach every new attachment to the default route table. Off gives each attachment its own table and real segmentation."
  default     = false
}

variable "default_route_table_propagation" {
  type        = bool
  description = "Propagate every attachment's routes into the default route table."
  default     = false
}

variable "dns_support" {
  type        = bool
  description = "Resolve public DNS to private addresses across attachments."
  default     = true
}

variable "multicast_support" {
  type        = bool
  description = "Enable multicast. Cannot be changed after creation."
  default     = false
}

variable "vpc_attachments" {
  type = map(object({
    vpc_id              = string
    subnet_ids          = list(string)
    appliance_mode      = optional(bool, false)
    dns_support         = optional(bool, true)
    route_table_key     = optional(string)
    propagate_to_tables = optional(list(string), [])
  }))
  description = "VPC attachments keyed by a stable name. Use one subnet per availability zone you want reachable. route_table_key names the one table an attachment is associated with, and cannot be combined with default_route_table_association."
  default     = {}

  validation {
    condition = !var.default_route_table_association || alltrue([
      for _, attachment in var.vpc_attachments : attachment.route_table_key == null
    ])
    error_message = "An attachment can be associated with only one route table. With default_route_table_association on, every attachment already joins the default table, so leave route_table_key unset or turn default association off."
  }
}

variable "route_tables" {
  type        = map(string)
  description = "Route tables keyed by a stable name, with a description as the value. Segmentation is what a transit gateway is for."
  default     = {}
}

variable "static_routes" {
  type = map(object({
    route_table_key        = string
    destination_cidr_block = string
    attachment_key         = optional(string)
    blackhole              = optional(bool, false)
  }))
  description = "Static routes keyed by a stable name. A route forwards to the attachment named by attachment_key, or is a blackhole that drops traffic and names no attachment."
  default     = {}

  validation {
    condition = alltrue([
      for _, route in var.static_routes :
      route.blackhole ? route.attachment_key == null : try(contains(keys(var.vpc_attachments), route.attachment_key), false)
    ])
    error_message = "Each static route needs attachment_key naming one of vpc_attachments, unless blackhole is true, in which case leave attachment_key unset."
  }

  validation {
    condition = alltrue([
      for _, route in var.static_routes : contains(keys(var.route_tables), route.route_table_key)
    ])
    error_message = "Each static route's route_table_key must name one of route_tables."
  }
}

variable "share_with_principals" {
  type        = list(string)
  description = "Account IDs or organization ARNs to share the gateway with through Resource Access Manager."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
