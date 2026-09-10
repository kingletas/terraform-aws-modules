variable "name" {
  type        = string
  description = "Cluster identifier and the prefix for everything around it."
}

variable "engine" {
  type        = string
  description = "aurora-postgresql or aurora-mysql."
  default     = "aurora-postgresql"

  validation {
    condition     = contains(["aurora-postgresql", "aurora-mysql"], var.engine)
    error_message = "The engine must be aurora-postgresql or aurora-mysql."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version. Leave null to take whatever is current, which moves under you."
  default     = null
}

variable "engine_mode" {
  type        = string
  description = "provisioned covers both fixed instances and Serverless v2. The old serverless mode is v1 and is not what you want."
  default     = "provisioned"
}

variable "instances" {
  type = map(object({
    instance_class      = optional(string, "db.serverless")
    promotion_tier      = optional(number, 1)
    availability_zone   = optional(string)
    publicly_accessible = optional(bool, false)
  }))
  description = "Cluster instances keyed by a stable name. The writer is whichever is promoted; the rest are readers."
  default     = { writer = {} }
}

variable "serverless_capacity" {
  type = object({
    min_capacity = optional(number, 0.5)
    max_capacity = optional(number, 4)
  })
  description = "Serverless v2 capacity range in ACUs. Only used when an instance class is db.serverless."
  default     = {}
}

variable "database_name" {
  type        = string
  description = "Name of the database created on first boot."
  default     = null
}

variable "username" {
  type        = string
  description = "Master username."
  default     = "dbadmin"
}

variable "manage_master_password" {
  type        = bool
  description = "Let RDS generate and rotate the master password in Secrets Manager, so it never reaches Terraform state."
  default     = true
}

variable "password" {
  type        = string
  description = "Master password. Only used when manage_master_password is false, and it lands in state in clear text."
  default     = null
  sensitive   = true
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the DB subnet group. Private subnets in at least two availability zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Aurora needs subnets in at least two availability zones."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups controlling who may connect."
  default     = []
}

variable "port" {
  type        = number
  description = "Port to listen on. Null uses the engine default."
  default     = null
}

variable "backup_retention_period" {
  type        = number
  description = "Days of automated backups."
  default     = 14
}

variable "preferred_backup_window" {
  type        = string
  description = "Daily backup window in UTC, as hh:mm-hh:mm."
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC."
  default     = "sun:04:00-sun:05:00"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for storage encryption. Null uses the AWS-managed RDS key."
  default     = null
}

variable "cluster_parameters" {
  type        = map(string)
  description = "Cluster-level engine parameters. A parameter group is created only when this is non-empty."
  default     = {}
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family, such as aurora-postgresql16. Required when cluster_parameters is non-empty."
  default     = null
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Log types shipped to CloudWatch."
  default     = []
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Turn on Performance Insights on every instance."
  default     = true
}

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Allow connecting with an IAM token instead of a stored password."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Refuse to delete the cluster until this is turned off."
  default     = true
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Delete without taking a final snapshot."
  default     = false
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes now rather than in the next maintenance window."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
