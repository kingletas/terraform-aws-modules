variable "name" {
  type        = string
  description = "Name prefix for the replication instance, its endpoints and its tasks."
}

variable "instance_class" {
  type        = string
  description = "Replication instance class. Sizing follows source change volume, not source size."
  default     = "dms.t3.medium"
}

variable "engine_version" {
  type        = string
  description = "DMS engine version. Null takes the current default, which moves under you."
  default     = null
}

variable "allocated_storage" {
  type        = number
  description = "Storage in gibibytes for the instance's own working files and logs."
  default     = 50
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the replication subnet group. Private subnets in at least two availability zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "DMS needs subnets in at least two availability zones."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups on the replication instance. It needs outbound to both source and target."
  default     = []
}

variable "multi_az" {
  type        = bool
  description = "Run a standby in another zone. A single-AZ instance failing mid-load means restarting the task."
  default     = false
}

variable "publicly_accessible" {
  type        = bool
  description = "Give the instance a public address, for a source outside your VPC with no VPN."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the instance storage and the endpoints. Null uses the AWS-managed DMS key."
  default     = null
}

variable "secrets_manager_endpoint_dns" {
  type        = string
  description = <<-EOT
    DNS name of the Secrets Manager VPC interface endpoint.

    A DMS endpoint in a private subnet reads its credentials over the public
    Secrets Manager address unless it is told otherwise, and with no route it
    simply hangs. Passing this sets secretsManagerEndpointOverride on every
    endpoint, which is the single most common reason a private DMS task never
    connects.
  EOT
  default     = null
}

variable "secrets_access_role_arn" {
  type        = string
  description = "Role DMS assumes to read endpoint credentials from Secrets Manager. Required when any endpoint uses a secret."
  default     = null
}

variable "endpoints" {
  type = map(object({
    endpoint_type = string
    engine_name   = string

    secret_arn  = optional(string)
    server_name = optional(string)
    port        = optional(number)
    username    = optional(string)
    password    = optional(string)

    database_name               = optional(string)
    ssl_mode                    = optional(string, "require")
    extra_connection_attributes = optional(string)
  }))
  description = "Source and target endpoints keyed by a stable name. Prefer secret_arn over an inline username and password, which land in Terraform state."

  validation {
    condition = alltrue([
      for name, endpoint in var.endpoints : contains(["source", "target"], endpoint.endpoint_type)
    ])
    error_message = "Each endpoint_type must be source or target."
  }

  validation {
    condition = alltrue([
      for name, endpoint in var.endpoints :
      endpoint.secret_arn != null || (endpoint.server_name != null && endpoint.username != null)
    ])
    error_message = "Each endpoint needs either a secret_arn, or a server_name with a username."
  }
}

variable "tasks" {
  type = map(object({
    source_endpoint     = string
    target_endpoint     = string
    migration_type      = optional(string, "full-load-and-cdc")
    table_mappings_json = string
    task_settings_json  = optional(string)
    start_on_create     = optional(bool, false)
  }))
  description = "Replication tasks keyed by a stable name. migration_type is full-load, cdc, or full-load-and-cdc."
  default     = {}

  validation {
    condition = alltrue([
      for name, task in var.tasks :
      contains(["full-load", "cdc", "full-load-and-cdc"], task.migration_type)
    ])
    error_message = "Each migration_type must be full-load, cdc or full-load-and-cdc."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
