variable "name" {
  type        = string
  description = "Name prefix for the connection and its gateways."
}

variable "customer_gateway_ip" {
  type        = string
  description = "Public IP of the device at the other end. The far side owns this, so confirm it rather than guessing."
}

variable "customer_gateway_bgp_asn" {
  type        = number
  description = "BGP ASN of the far side. Use 65000 when the far side does not run BGP."
  default     = 65000
}

variable "customer_gateway_certificate_arn" {
  type        = string
  description = "ACM certificate for certificate-based authentication instead of a pre-shared key."
  default     = null
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit gateway to attach to. Set this or vpn_gateway, not both."
  default     = null
}

variable "vpn_gateway" {
  type = object({
    vpc_id = string
  })
  description = "Creates a virtual private gateway in this VPC and attaches the connection to it. Set this or transit_gateway_id, not both."
  default     = null
}

variable "static_routes_only" {
  type        = bool
  description = "Use static routes rather than BGP. BGP fails over on its own; static routes do not."
  default     = false
}

variable "static_routes" {
  type        = map(string)
  description = "CIDRs reachable at the far side, keyed by a stable name. Required when static_routes_only is on. With vpn_gateway they become VPN connection routes; with transit_gateway_id they become routes in transit_gateway_static_route_tables."
  default     = {}

  validation {
    condition     = alltrue([for cidr in values(var.static_routes) : can(cidrnetmask(cidr))])
    error_message = "Every static_routes value must be an IPv4 CIDR block."
  }
}

variable "local_ipv4_network_cidr" {
  type        = string
  description = "CIDR on the far side allowed inside the tunnel."
  default     = "0.0.0.0/0"
}

variable "remote_ipv4_network_cidr" {
  type        = string
  description = "CIDR on the AWS side allowed inside the tunnel."
  default     = "0.0.0.0/0"
}

variable "tunnel_inside_cidrs" {
  type        = list(string)
  description = "The /30 ranges for each tunnel's inside addresses. Empty lets AWS choose. Must come from 169.254.0.0/16."
  default     = []
}

variable "tunnel_preshared_keys" {
  type        = list(string)
  description = "Pre-shared keys for each tunnel. Empty lets AWS generate them. Either way the keys are stored in Terraform state."
  default     = []
  sensitive   = true
}

variable "vpn_gateway_propagation_route_tables" {
  type        = map(string)
  description = "VPC route tables that learn routes from the virtual private gateway, keyed by a stable name. Only with vpn_gateway."
  default     = {}
}

variable "transit_gateway_association" {
  type = object({
    route_table_id = string
  })
  description = "Transit gateway route table the VPN attachment looks up routes in. Only with transit_gateway_id, and not when the gateway associates new attachments with its default table. Null leaves the attachment unassociated."
  default     = null
}

variable "transit_gateway_propagation_route_tables" {
  type        = map(string)
  description = "Transit gateway route tables that learn the far side's BGP routes, keyed by a stable name. Only with transit_gateway_id."
  default     = {}
}

variable "transit_gateway_static_route_tables" {
  type        = map(string)
  description = "Transit gateway route tables that get a route to each static_routes CIDR through the VPN attachment, keyed by a stable name. Required for static routing with transit_gateway_id."
  default     = {}
}

variable "enable_tunnel_logging" {
  type        = bool
  description = "Log tunnel state changes to CloudWatch, which is how you find out why a tunnel dropped."
  default     = true
}

variable "log_group_arn" {
  type        = string
  description = "CloudWatch log group for tunnel logs. Required when enable_tunnel_logging is on."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
