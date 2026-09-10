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
  description = "Transit gateway to attach to. Set this or vpc_id, not both."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC to create a virtual private gateway in. Set this or transit_gateway_id, not both."
  default     = null
}

variable "static_routes_only" {
  type        = bool
  description = "Use static routes rather than BGP. BGP fails over on its own; static routes do not."
  default     = false
}

variable "static_routes" {
  type        = list(string)
  description = "CIDRs reachable at the far side. Required when static_routes_only is on."
  default     = []
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
  description = "Pre-shared keys for each tunnel. Empty lets AWS generate them, which keeps them out of Terraform state."
  default     = []
  sensitive   = true
}

variable "propagate_to_route_table_ids" {
  type        = list(string)
  description = "Route tables that learn routes from the virtual private gateway. Only used with vpc_id."
  default     = []
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
