variable "name" {
  type        = string
  description = "Cluster name."
}

variable "container_insights" {
  type        = string
  description = "Container Insights level: enhanced, enabled or disabled. Enhanced adds per-task metrics and costs more."
  default     = "enabled"

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "The container_insights must be enhanced, enabled or disabled."
  }
}

variable "capacity_providers" {
  type        = list(string)
  description = "Capacity providers available to the cluster."
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 1)
    base              = optional(number, 0)
  }))
  description = "How tasks are placed when a service names no strategy of its own."
  default     = [{ capacity_provider = "FARGATE", base = 1, weight = 1 }]
}

variable "execute_command_logging" {
  type        = string
  description = "Where ECS Exec sessions are recorded: NONE, DEFAULT, OVERRIDE. A session that is not recorded is a shell nobody audited."
  default     = "OVERRIDE"

  validation {
    condition     = contains(["NONE", "DEFAULT", "OVERRIDE"], var.execute_command_logging)
    error_message = "The execute_command_logging must be NONE, DEFAULT or OVERRIDE."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Days to keep the cluster's exec log group."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention period must be one of the values CloudWatch Logs accepts; seven years is 2557, not 2555."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting ECS Exec sessions and the log group."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
