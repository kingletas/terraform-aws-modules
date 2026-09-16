variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the hub."
  default     = "hub"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "production"
}

variable "shared_vpc_cidr" {
  type        = string
  description = "CIDR for the shared services VPC, which holds the NAT gateways and endpoints."
  default     = "10.0.0.0/16"
}

variable "spokes" {
  type = map(object({
    cidr_block         = string
    enable_nat_gateway = optional(bool, false)
  }))
  description = "Spoke VPCs keyed by name. Their CIDRs must not overlap each other or the shared VPC."

  default = {
    production = { cidr_block = "10.10.0.0/16" }
    staging    = { cidr_block = "10.20.0.0/16" }
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Zones every VPC spreads across. Null takes the first two in the region."
  default     = null
}

variable "on_premises" {
  type = object({
    gateway_ip         = string
    bgp_asn            = optional(number, 65000)
    static_routes_only = optional(bool, false)
    routes             = optional(list(string), [])
  })
  description = "Site-to-site VPN to an on-premises network. Null skips it entirely. The routes list the on-premises CIDRs and are required with BGP too, because the VPC route tables need them and routes learned by BGP are not known at plan."
  default     = null

  validation {
    condition     = var.on_premises == null ? true : length(var.on_premises.routes) > 0
    error_message = "on_premises.routes needs at least one on-premises CIDR, even with BGP, or traffic to on-premises leaves through the NAT gateways."
  }
}

variable "interface_endpoint_services" {
  type        = list(string)
  description = "Interface endpoints in the shared VPC. Centralising them means paying for one set rather than one per spoke."
  default     = ["ssm", "ssmmessages", "ec2messages", "secretsmanager", "logs", "ecr.api", "ecr.dkr"]
}
