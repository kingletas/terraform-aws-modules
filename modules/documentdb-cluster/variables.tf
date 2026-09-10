variable "name" {
  type        = string
  description = "Cluster identifier and the prefix for everything around it."
}

variable "engine_version" {
  type        = string
  description = "DocumentDB engine version."
  default     = "5.0.0"
}

variable "instance_count" {
  type        = number
  description = "Cluster instances. The first is the writer; the rest are readers."
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "A cluster needs at least one instance."
  }
}

variable "instance_class" {
  type        = string
  description = "Instance class, such as db.t4g.medium."
  default     = "db.t4g.medium"
}

variable "username" {
  type        = string
  description = "Master username."
  default     = "dbadmin"
}

variable "manage_master_password" {
  type        = bool
  description = "Let DocumentDB generate and rotate the master password in Secrets Manager, so it never reaches Terraform state."
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
    error_message = "DocumentDB needs subnets in at least two availability zones."
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
  default     = 27017
}

variable "parameters" {
  type        = map(string)
  description = "Cluster parameters. A parameter group is created only when this is non-empty. TLS is enabled here by default."
  default     = { tls = "enabled", audit_logs = "enabled" }
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family, such as docdb5.0."
  default     = "docdb5.0"
}

variable "backup_retention_period" {
  type        = number
  description = "Days of automated backups."
  default     = 14
}

variable "preferred_backup_window" {
  type        = string
  description = "Daily backup window in UTC."
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC."
  default     = "sun:04:00-sun:05:00"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for storage encryption. Null uses the AWS-managed key."
  default     = null
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Log types shipped to CloudWatch: audit and profiler."
  default     = ["audit"]
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

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
