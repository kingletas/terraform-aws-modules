variable "name" {
  type        = string
  description = "Name prefix for the endpoint and everything attached to it."
}

variable "client_cidr_block" {
  type        = string
  description = "Address pool handed to connecting clients. Must be at least a /22 and must not overlap the VPC."

  validation {
    condition     = can(cidrhost(var.client_cidr_block, 0)) && tonumber(split("/", var.client_cidr_block)[1]) <= 22
    error_message = "The client_cidr_block must be a valid IPv4 CIDR of /22 or larger."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC the endpoint is associated with."
}

variable "subnet_ids" {
  type        = map(string)
  description = "Subnets to associate the endpoint with, keyed by availability zone. Each association is billed hourly. The vpc module's private_subnet_ids output has this shape."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet association is required for the endpoint to accept connections."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups applied to the endpoint's network interfaces."
  default     = []
}

variable "authentication_type" {
  type        = string
  description = "How clients authenticate: certificate-authentication, directory-service-authentication or federated-authentication."
  default     = "certificate-authentication"

  validation {
    condition = contains([
      "certificate-authentication",
      "directory-service-authentication",
      "federated-authentication",
    ], var.authentication_type)
    error_message = "The authentication_type must be certificate-authentication, directory-service-authentication or federated-authentication."
  }
}

variable "server_certificate_arn" {
  type        = string
  description = "ACM ARN of the server certificate. Leave null to import server_certificate instead."
  default     = null
}

variable "server_certificate" {
  type = object({
    certificate_body  = string
    private_key       = string
    certificate_chain = optional(string)
  })
  description = "PEM material for the server certificate, imported into ACM. Ignored when server_certificate_arn is set."
  default     = null
  sensitive   = true
}

variable "client_root_certificate_chain_arn" {
  type        = string
  description = "ACM ARN of the client certificate authority. Required for certificate authentication unless client_root_certificate is set."
  default     = null
}

variable "client_root_certificate" {
  type = object({
    certificate_body  = string
    private_key       = string
    certificate_chain = optional(string)
  })
  description = "PEM material for the client certificate authority, imported into ACM. Ignored when client_root_certificate_chain_arn is set."
  default     = null
  sensitive   = true
}

variable "directory_id" {
  type        = string
  description = "Directory Service directory ID. Required for directory-service-authentication."
  default     = null
}

variable "saml_provider_arn" {
  type        = string
  description = "IAM SAML provider ARN. Required for federated-authentication."
  default     = null
}

variable "self_service_saml_provider_arn" {
  type        = string
  description = "IAM SAML provider ARN backing the self-service portal."
  default     = null
}

variable "authorization_rules" {
  type = map(object({
    target_network_cidr  = string
    description          = optional(string)
    access_group_id      = optional(string)
    authorize_all_groups = optional(bool, false)
  }))
  description = "Networks clients may reach, keyed by a stable name. Give each rule either an access_group_id or authorize_all_groups."

  validation {
    condition = alltrue([
      for name, rule in var.authorization_rules :
      (rule.access_group_id != null) != rule.authorize_all_groups
    ])
    error_message = "Each authorization rule needs exactly one of access_group_id or authorize_all_groups."
  }
}

variable "routes" {
  type = map(object({
    destination_cidr_block = string
    target_subnet_id       = string
    description            = optional(string)
  }))
  description = "Extra routes, keyed by a stable name. Associated subnet CIDRs are routed automatically and need no entry here."
  default     = {}
}

variable "split_tunnel" {
  type        = bool
  description = "Send only VPC-bound traffic through the tunnel. Turning this off routes all client internet traffic through AWS."
  default     = true
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers pushed to clients. Use the VPC resolver, the base of the VPC CIDR plus two, to resolve private names."
  default     = []
}

variable "vpn_port" {
  type        = number
  description = "Port the endpoint listens on."
  default     = 443

  validation {
    condition     = contains([443, 1194], var.vpn_port)
    error_message = "AWS Client VPN accepts port 443 or 1194 only."
  }
}

variable "transport_protocol" {
  type        = string
  description = "Transport protocol. UDP performs better; TCP traverses restrictive networks."
  default     = "udp"

  validation {
    condition     = contains(["tcp", "udp"], var.transport_protocol)
    error_message = "The transport_protocol must be tcp or udp."
  }
}

variable "session_timeout_hours" {
  type        = number
  description = "Hours before a connected client is forced to reauthenticate."
  default     = 8

  validation {
    condition     = contains([8, 10, 12, 24], var.session_timeout_hours)
    error_message = "AWS accepts a session timeout of 8, 10, 12 or 24 hours."
  }
}

variable "self_service_portal_enabled" {
  type        = bool
  description = "Offer the AWS self-service portal for client configuration downloads. Federated authentication only."
  default     = false
}

variable "connection_log_retention_days" {
  type        = number
  description = "Days to retain connection logs. Set to 0 to disable connection logging."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.connection_log_retention_days)
    error_message = "The retention period must be 0 or one of the values CloudWatch Logs accepts."
  }
}

variable "connection_log_kms_key_arn" {
  type        = string
  description = "KMS key used to encrypt the connection log group. Defaults to the CloudWatch Logs service key."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
