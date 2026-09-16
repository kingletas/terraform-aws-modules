variable "name" {
  type        = string
  description = "Replication group identifier and the prefix for everything around it."
}

variable "engine" {
  type        = string
  description = "redis or valkey. Valkey is the fork most of the ecosystem moved to and is cheaper per node."
  default     = "valkey"

  validation {
    condition     = contains(["redis", "valkey"], var.engine)
    error_message = "The engine must be redis or valkey."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version. Leave null to take the current default."
  default     = null
}

variable "node_type" {
  type        = string
  description = "Node type, such as cache.t4g.micro."
  default     = "cache.t4g.micro"
}

variable "num_node_groups" {
  type        = number
  description = "Number of shards. More than one turns on cluster mode, which most client libraries need to be told about, and needs parameter_group_family so a cluster-enabled parameter group is used."
  default     = 1
}

variable "replicas_per_node_group" {
  type        = number
  description = "Read replicas per shard. At least one is needed for automatic failover."
  default     = 1
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the cache subnet group. Private subnets in at least two availability zones."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups controlling who may connect."
  default     = []
}

variable "port" {
  type        = number
  description = "Port to listen on."
  default     = 6379
}

variable "parameters" {
  type        = map(string)
  description = "Engine parameters. A parameter group is created only when this is non-empty."
  default     = {}
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family, such as valkey8. Required when parameters is non-empty or num_node_groups is above 1."
  default     = null
}

variable "automatic_failover_enabled" {
  type        = bool
  description = "Promote a replica when the primary fails. Needs at least one replica."
  default     = true
}

variable "multi_az_enabled" {
  type        = bool
  description = "Place replicas in other availability zones. Needs automatic failover."
  default     = true
}

variable "at_rest_encryption_enabled" {
  type        = bool
  description = "Encrypt data on disk."
  default     = true
}

variable "transit_encryption_enabled" {
  type        = bool
  description = "Encrypt data in flight. Clients must then connect with TLS, which is a client change as well as a server one."
  default     = true
}

variable "auth_token" {
  type        = string
  description = "Password required on connect. Needs transit encryption, and must be 16 to 128 printable characters."
  default     = null
  sensitive   = true
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for encryption at rest. Null uses the AWS-managed key."
  default     = null
}

variable "snapshot_retention_limit" {
  type        = number
  description = "Days of automatic snapshots. Zero disables them."
  default     = 5
}

variable "snapshot_window" {
  type        = string
  description = "Daily snapshot window in UTC, as hh:mm-hh:mm."
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC."
  default     = "sun:04:00-sun:05:00"
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Take minor engine upgrades automatically."
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes now rather than in the next maintenance window."
  default     = false
}

variable "log_delivery" {
  type = map(object({
    destination      = string
    destination_type = optional(string, "cloudwatch-logs")
    log_format       = optional(string, "json")
  }))
  description = "Log delivery keyed by log type, either slow-log or engine-log."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
