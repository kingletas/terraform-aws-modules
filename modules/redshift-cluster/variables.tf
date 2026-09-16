variable "name" {
  type        = string
  description = "Cluster identifier and the prefix for everything around it."
}

variable "database_name" {
  type        = string
  description = "Name of the first database created in the cluster."
  default     = "warehouse"
}

variable "node_type" {
  type        = string
  description = "Node type. The ra3 family separates compute from storage and is what new clusters should use; dc2 is the older fixed-storage family."
  default     = "ra3.large"
}

variable "number_of_nodes" {
  type        = number
  description = "Nodes in the cluster. One means a single-node cluster with no replication."
  default     = 2

  validation {
    condition     = var.number_of_nodes >= 1 && var.number_of_nodes <= 128
    error_message = "The number_of_nodes must be between 1 and 128."
  }
}

variable "username" {
  type        = string
  description = "Master username. Cannot be a Redshift reserved word."
  default     = "warehouse_admin"
}

variable "manage_master_password" {
  type        = bool
  description = "Let Redshift generate and rotate the master password in Secrets Manager, so it never reaches Terraform state."
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
  description = "Subnets for the cluster subnet group. Private subnets in at least two availability zones."

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Redshift needs subnets in at least two availability zones."
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
  default     = 5439
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for encryption at rest. Null uses the AWS-managed Redshift key."
  default     = null
}

variable "iam_role_arns" {
  type        = list(string)
  description = "Roles the cluster may assume, for COPY from S3 and for DMS to load into it."
  default     = []
}

variable "default_iam_role_arn" {
  type        = string
  description = "Role used when a COPY or UNLOAD names none. Must also appear in iam_role_arns."
  default     = null
}

variable "require_ssl" {
  type        = bool
  description = "Refuse client connections that do not use TLS. On, and set in the cluster's own parameter group whatever else parameters holds."
  default     = true
}

variable "parameters" {
  type        = map(string)
  description = "Cluster parameters, added to the parameter group this module always creates. Set require_ssl through its own variable, not here."
  default     = { enable_user_activity_logging = "true" }

  validation {
    condition     = !contains(keys(var.parameters), "require_ssl")
    error_message = "Set require_ssl with the require_ssl variable, not in parameters."
  }
}

variable "parameter_group_family" {
  type        = string
  description = "Parameter group family."
  default     = "redshift-1.0"
}

variable "logging" {
  type = object({
    bucket = string
    prefix = optional(string)
  })
  description = "Where connection, user and user-activity logs go. The bucket's policy must already allow the Redshift service, and it needs ACLs enabled. Null disables logging."
  default     = null
}

variable "automated_snapshot_retention_period" {
  type        = number
  description = "Days of automated snapshots. Zero disables them."
  default     = 7
}

variable "manual_snapshot_retention_period" {
  type        = number
  description = "Days a manual snapshot is kept. Minus one keeps it forever."
  default     = 90
}

variable "maintenance_window" {
  type        = string
  description = "Weekly maintenance window in UTC."
  default     = "sun:05:00-sun:06:00"
}

variable "allow_version_upgrade" {
  type        = bool
  description = "Take major version upgrades during the maintenance window."
  default     = true
}

variable "enhanced_vpc_routing" {
  type        = bool
  description = "Force COPY and UNLOAD traffic through the VPC, where security groups and endpoints apply to it. Without this it leaves over the public network."
  default     = true
}

variable "publicly_accessible" {
  type        = bool
  description = "Give the cluster a public address. Almost never right."
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Delete without a final snapshot."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
