variable "name" {
  type        = string
  description = "Rule name."
}

variable "description" {
  type        = string
  description = "What this rule reacts to."
  default     = null
}

variable "event_bus_name" {
  type        = string
  description = "Bus the rule listens on. Null uses the account default bus."
  default     = null
}

variable "schedule_expression" {
  type        = string
  description = "cron or rate expression, in UTC. Set this or event_pattern, not both."
  default     = null
}

variable "event_pattern_json" {
  type        = string
  description = "Event pattern as JSON. Set this or schedule_expression, not both."
  default     = null
}

variable "enabled" {
  type        = bool
  description = "Whether the rule fires."
  default     = true
}

variable "targets" {
  type = map(object({
    arn      = string
    role_arn = optional(string)

    input      = optional(string)
    input_path = optional(string)
    input_transformer = optional(object({
      input_paths    = map(string)
      input_template = string
    }))

    dead_letter_arn        = optional(string)
    maximum_retry_attempts = optional(number, 3)
    maximum_event_age      = optional(number, 3600)

    sqs_message_group_id = optional(string)

    ecs_task_definition_arn = optional(string)
    ecs_task_count          = optional(number, 1)
    ecs_launch_type         = optional(string, "FARGATE")
    ecs_subnet_ids          = optional(list(string))
    ecs_security_group_ids  = optional(list(string))
    ecs_assign_public_ip    = optional(bool, false)
  }))
  description = "Targets keyed by a stable name. Each shapes its payload with at most one of input, input_path or input_transformer. Always set a dead_letter_arn, or a failed delivery is lost silently."

  validation {
    condition     = length(var.targets) > 0
    error_message = "A rule with no target does nothing."
  }

  validation {
    condition = alltrue([
      for _, target in var.targets :
      length([for input in [target.input, target.input_path, target.input_transformer] : input if input != null]) <= 1
    ])
    error_message = "Each target sets at most one of input, input_path or input_transformer."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the rule."
  default     = {}
}
