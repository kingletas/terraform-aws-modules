variable "name" {
  type        = string
  description = "Broker name, unique within the account and region."
}

variable "engine_type" {
  type        = string
  description = "RabbitMQ or ActiveMQ. The two differ in deployment modes, users and storage, and this module validates each against the engine."
  default     = "RabbitMQ"

  validation {
    condition     = contains(["RabbitMQ", "ActiveMQ"], var.engine_type)
    error_message = "The engine_type must be RabbitMQ or ActiveMQ."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version, such as 3.13. AWS deprecates old minors on a published schedule, so pin one you have tested."
}

variable "host_instance_type" {
  type        = string
  description = "Broker instance size, such as mq.t3.micro or mq.m5.large. The t3 sizes are burstable and are for development."
  default     = "mq.t3.micro"
}

variable "deployment_mode" {
  type        = string
  description = "SINGLE_INSTANCE for one node. CLUSTER_MULTI_AZ is RabbitMQ's three-node cluster; ACTIVE_STANDBY_MULTI_AZ is ActiveMQ's pair."
  default     = "SINGLE_INSTANCE"

  validation {
    condition     = contains(["SINGLE_INSTANCE", "CLUSTER_MULTI_AZ", "ACTIVE_STANDBY_MULTI_AZ"], var.deployment_mode)
    error_message = "The deployment_mode must be SINGLE_INSTANCE, CLUSTER_MULTI_AZ or ACTIVE_STANDBY_MULTI_AZ."
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets the broker sits in. One for a single instance, two in different zones for either multi-AZ mode."

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

variable "users" {
  type = map(object({
    password         = string
    console_access   = optional(bool, false)
    groups           = optional(list(string), [])
    replication_user = optional(bool, false)
  }))
  description = "Broker users keyed by username. RabbitMQ takes exactly one, and manages the rest through its own management interface."
  sensitive   = true

  validation {
    condition     = length(var.users) > 0
    error_message = "A broker needs at least one user, or nothing can connect to it."
  }

  validation {
    condition = alltrue([
      for _, user in var.users : length(user.password) >= 12 && length(user.password) <= 250
    ])
    error_message = "A broker password is 12 to 250 characters."
  }

  validation {
    condition     = alltrue([for _, user in var.users : length(distinct(split("", user.password))) >= 4])
    error_message = "A broker password needs at least four different characters."
  }

  validation {
    condition     = alltrue([for _, user in var.users : !can(regex("[,:=]", user.password))])
    error_message = "A broker password may not contain a comma, a colon or an equals sign."
  }
}

variable "publicly_accessible" {
  type        = bool
  description = "Give the broker a public endpoint. Off, because a message broker on the internet is one credential away from being someone else's."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for encryption at rest. ActiveMQ only; RabbitMQ always uses the AWS-owned key. Null uses the AWS-owned key, which is still encryption, just not a key you control."
  default     = null
}

variable "storage_type" {
  type        = string
  description = "ebs or efs. RabbitMQ is ebs only. ActiveMQ defaults to efs, which is durable across zones and slower."
  default     = null

  validation {
    condition     = var.storage_type == null || contains(["ebs", "efs"], coalesce(var.storage_type, "ebs"))
    error_message = "The storage_type must be ebs or efs."
  }
}

variable "general_log_enabled" {
  type        = bool
  description = "Publish the general broker log to CloudWatch Logs."
  default     = true
}

variable "audit_log_enabled" {
  type        = bool
  description = "Publish the audit log to CloudWatch Logs. ActiveMQ only; RabbitMQ has no audit log."
  default     = false
}

variable "configuration" {
  type = object({
    data        = string
    description = optional(string)
  })
  description = "Broker configuration to create and apply. ActiveMQ takes XML, RabbitMQ takes Cuttlefish. Null leaves the engine defaults in place."
  default     = null
}

variable "maintenance_window" {
  type = object({
    day_of_week = string
    time_of_day = string
    time_zone   = optional(string, "UTC")
  })
  description = "Weekly window AWS may restart the broker in. Null lets AWS choose one, which is a restart at a time nobody picked."
  default     = null

  validation {
    condition = var.maintenance_window == null || contains(
      ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"],
      try(var.maintenance_window.day_of_week, "MONDAY")
    )
    error_message = "The day_of_week must be a day name in capitals, such as SUNDAY."
  }
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Take minor engine upgrades in the maintenance window. On, because AWS deprecates old minors and an unpatched broker eventually stops being supported."
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes now rather than in the next maintenance window. A change that restarts the broker drops every connection."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
