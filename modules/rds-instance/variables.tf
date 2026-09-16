variable "name" {
  type        = string
  description = "Identifier for the instance and the resources around it."
}

variable "engine" {
  type        = string
  description = "Database engine: mysql, postgres, mariadb, oracle-se2, sqlserver-ex and so on."
  default     = "postgres"
}

variable "engine_version" {
  type        = string
  description = "Engine version. Leave null to take the latest the family offers, which moves under you."
  default     = null
}

variable "instance_class" {
  type        = string
  description = "Instance class, such as db.t4g.medium."
  default     = "db.t4g.medium"
}

variable "allocated_storage" {
  type        = number
  description = "Storage in gibibytes."
  default     = 50
}

variable "max_allocated_storage" {
  type        = number
  description = "Ceiling for storage autoscaling. Set to 0 to keep storage fixed."
  default     = 500
}

variable "storage_type" {
  type        = string
  description = "gp3 for general use, io1 or io2 where you need guaranteed IOPS."
  default     = "gp3"
}

variable "database_name" {
  type        = string
  description = "Name of the database created on first boot."
  default     = null
}

variable "username" {
  type        = string
  description = "Master username. Cannot be a reserved word for the engine."
  default     = "dbadmin"
}

variable "manage_master_password" {
  type        = bool
  description = "Let RDS generate and rotate the master password in Secrets Manager, so it never passes through Terraform state."
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
  description = "Subnets for the DB subnet group. Use private subnets in at least two availability zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS needs subnets in at least two availability zones."
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

variable "multi_az" {
  type        = bool
  description = "Keep a synchronous standby in another availability zone. Doubles the instance cost and is what makes a failover survivable."
  default     = true
}

variable "backup_retention_period" {
  type        = number
  description = "Days of automated backups. Zero disables them and with them point-in-time recovery."
  default     = 14

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "The retention period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  type        = string
  description = "Daily backup window in UTC, as hh:mm-hh:mm."
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC, as ddd:hh:mm-ddd:hh:mm."
  default     = "sun:04:00-sun:05:00"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for storage encryption. Null uses the AWS-managed RDS key."
  default     = null
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Turn on Performance Insights. Free for seven days of history."
  default     = true
}

variable "monitoring_interval" {
  type        = number
  description = "Enhanced monitoring interval in seconds. Zero disables it."
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "The monitoring interval must be 0, 1, 5, 10, 15, 30 or 60 seconds."
  }
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Log types shipped to CloudWatch. Postgres takes postgresql and upgrade; MySQL takes error, general, slowquery and audit."
  default     = []
}

variable "parameters" {
  type        = map(string)
  description = "Engine parameters, as a map of name to value. A parameter group is created only when this is non-empty."
  default     = {}
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family, such as postgres16. Required when parameters is non-empty."
  default     = null
}

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Allow connecting with an IAM token instead of a stored password. Not every engine and class supports it."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Refuse to delete the instance until this is turned off."
  default     = true
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Delete without taking a final snapshot. Off, so a destroy leaves something to restore from."
  default     = false
}

variable "delete_automated_backups" {
  type        = bool
  description = "Delete the automated backups when the instance is deleted. Off, so they stay restorable for their retention period after a destroy."
  default     = false
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes now rather than in the next maintenance window. Some changes cause an outage."
  default     = false
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Take minor engine upgrades automatically during the maintenance window."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
