variable "name" {
  type        = string
  description = "Name prefix applied to the VPC and everything inside it."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "The name must be 3-32 lowercase letters, digits or hyphens, and may not start or end with a hyphen."
  }
}

variable "cidr_block" {
  type        = string
  description = "IPv4 CIDR block for the VPC."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "The cidr_block must be a valid IPv4 CIDR, for example 10.0.0.0/16."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to spread subnets across. One public and one private subnet are created per zone."

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone is required."
  }
}

variable "subnet_newbits" {
  type        = number
  description = "Bits added to the VPC prefix when carving subnets. A /16 with 8 newbits yields /24 subnets."
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 16
    error_message = "The subnet_newbits value must be between 1 and 16."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Give private subnets outbound internet access through a NAT gateway."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Route every private subnet through one NAT gateway instead of one per zone. Cheaper, and a single point of failure."
  default     = false
}

variable "map_public_ip_on_launch" {
  type        = bool
  description = "Assign a public IP to instances launched into a public subnet. Off by default; attach an Elastic IP or use a NAT gateway instead."
  default     = false
}

variable "flow_log_retention_days" {
  type        = number
  description = "Days to retain VPC flow logs. Set to 0 to disable flow logging entirely."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "The retention period must be 0 or one of the values CloudWatch Logs accepts."
  }
}

variable "flow_log_kms_key_arn" {
  type        = string
  description = "KMS key used to encrypt the flow log group. Defaults to the CloudWatch Logs service key."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
