variable "name" {
  type        = string
  description = "Name prefix for the endpoints."
}

variable "vpc_id" {
  type        = string
  description = "VPC the endpoints belong to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for interface endpoints. One per availability zone."
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups on the interface endpoints. They need HTTPS from the callers."
  default     = []
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route tables that gateway endpoints add a prefix list route to."
  default     = []
}

variable "interface_services" {
  type        = list(string)
  description = "Service short names for interface endpoints, such as ecr.api, logs, secretsmanager. Each is billed hourly per availability zone, plus data."
  default     = []
}

variable "gateway_services" {
  type        = list(string)
  description = "Service short names for gateway endpoints. Only s3 and dynamodb exist, and both are free."
  default     = ["s3"]

  validation {
    condition     = alltrue([for service in var.gateway_services : contains(["s3", "dynamodb"], service)])
    error_message = "Only s3 and dynamodb are available as gateway endpoints."
  }
}

variable "private_dns_enabled" {
  type        = bool
  description = "Let the service's public hostname resolve to the endpoint, so callers need no code change."
  default     = true
}

variable "policy_json" {
  type        = string
  description = "Endpoint policy applied to every endpoint. Null uses full access, which the surrounding IAM still constrains."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every endpoint."
  default     = {}
}
