variable "alarms" {
  type = map(object({
    metric_name = optional(string)
    namespace   = optional(string)
    dimensions  = optional(map(string), {})

    comparison_operator = string
    threshold           = optional(number)
    evaluation_periods  = optional(number, 2)
    datapoints_to_alarm = optional(number)
    period              = optional(number, 300)
    statistic           = optional(string, "Average")
    extended_statistic  = optional(string)
    unit                = optional(string)

    description        = optional(string)
    treat_missing_data = optional(string, "missing")

    metric_query = optional(list(object({
      id          = string
      expression  = optional(string)
      label       = optional(string)
      return_data = optional(bool, false)

      metric_name = optional(string)
      namespace   = optional(string)
      dimensions  = optional(map(string), {})
      period      = optional(number, 300)
      stat        = optional(string, "Average")
    })))

    alarm_actions             = optional(list(string))
    ok_actions                = optional(list(string))
    insufficient_data_actions = optional(list(string))
  }))
  description = "Alarms keyed by alarm name. Give each one either metric_name with namespace, or a metric_query for a maths expression."

  validation {
    condition = alltrue([
      for name, alarm in var.alarms :
      (alarm.metric_name != null && alarm.namespace != null) || alarm.metric_query != null
    ])
    error_message = "Each alarm needs either metric_name with namespace, or a metric_query."
  }

  validation {
    condition = alltrue([
      for name, alarm in var.alarms :
      alarm.metric_query == null || length([for query in coalesce(alarm.metric_query, []) : query.id if query.return_data]) == 1
    ])
    error_message = "Each metric_query alarm needs exactly one query with return_data = true, which is the series the alarm evaluates."
  }

  validation {
    condition = alltrue(flatten([
      for name, alarm in var.alarms : [
        for period in concat(
          alarm.metric_query == null ? [alarm.period] : [],
          [for query in coalesce(alarm.metric_query, []) : query.period if query.metric_name != null],
        ) :
        period * alarm.evaluation_periods <= (period < 60 ? 3600 : 86400)
      ]
    ]))
    error_message = "Each alarm's period times evaluation_periods must be at most 86400 seconds, or 3600 seconds for a period under 60. CloudWatch refuses a longer evaluation window."
  }

  validation {
    condition = alltrue([
      for name, alarm in var.alarms :
      contains(["missing", "notBreaching", "breaching", "ignore"], alarm.treat_missing_data)
    ])
    error_message = "The treat_missing_data must be missing, notBreaching, breaching or ignore."
  }
}

variable "default_alarm_actions" {
  type        = list(string)
  description = "Actions used by any alarm that names none of its own. Usually one SNS topic."
  default     = []
}

variable "default_ok_actions" {
  type        = list(string)
  description = "Recovery actions used by any alarm that names none of its own. An alarm that never tells you it cleared is half a signal."
  default     = []
}

variable "actions_enabled" {
  type        = bool
  description = "Whether alarms fire their actions. Turn off while tuning a threshold rather than deleting the alarm."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every alarm."
  default     = {}
}
