variable "name" {
  type        = string
  description = "Name for the peering connection."
}

variable "requester_vpc_id" {
  type        = string
  description = "VPC asking for the connection, in this account and region."
}

variable "accepter_vpc_id" {
  type        = string
  description = "VPC being connected to."
}

variable "peer_owner_id" {
  type        = string
  description = "Account ID owning the other VPC. Null means the same account."
  default     = null
}

variable "peer_region" {
  type        = string
  description = "Region of the other VPC. Null means the same region."
  default     = null
}

variable "auto_accept" {
  type        = bool
  description = "Accept the connection at once. Only possible when both VPCs are in this account and region."
  default     = true
}

variable "allow_remote_dns_resolution" {
  type        = bool
  description = "Let each side resolve the other's private hostnames to private addresses."
  default     = true
}

variable "requester_route_table_ids" {
  type        = map(string)
  description = "Keyed by a stable name, so the keys are known at plan. Route tables on this side that should reach the other VPC."
  default     = {}
}

variable "accepter_route_table_ids" {
  type        = map(string)
  description = "Keyed by a stable name, so the keys are known at plan. Route tables on the other side. Only usable when both VPCs are in this account and region."
  default     = {}
}

variable "requester_destination_cidr" {
  type        = string
  description = "CIDR of the other VPC, used in this side's routes. Required when requester_route_table_ids is non-empty."
  default     = null
}

variable "accepter_destination_cidr" {
  type        = string
  description = "CIDR of this VPC, used in the other side's routes. Required when accepter_route_table_ids is non-empty."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the peering connection."
  default     = {}
}
