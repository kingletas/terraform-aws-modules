variable "name" {
  type        = string
  description = "Log group name, conventionally a path such as /aws/service/thing."
}

variable "retention_days" {
  type        = number
  description = "Days to keep logs. Zero keeps them forever, which is a bill that only grows."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.retention_days)
    error_message = "The retention period must be 0 or one of the values CloudWatch Logs accepts."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the group. The key policy must allow the logs service principal for this region."
  default     = null
}

variable "log_class" {
  type        = string
  description = "STANDARD for logs you query and alarm on. INFREQUENT_ACCESS is cheaper and supports far less."
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "INFREQUENT_ACCESS"], var.log_class)
    error_message = "The log_class must be STANDARD or INFREQUENT_ACCESS."
  }
}

variable "skip_destroy" {
  type        = bool
  description = "Leave the group in place when Terraform destroys it, keeping the logs."
  default     = false
}

variable "metric_filters" {
  type = map(object({
    pattern          = string
    metric_name      = string
    metric_namespace = string
    metric_value     = optional(string, "1")
    default_value    = optional(number)
    unit             = optional(string)
  }))
  description = "Metric filters keyed by a stable name. This is how a log line becomes a number an alarm can watch."
  default     = {}
}

variable "subscription_filters" {
  type = map(object({
    pattern         = string
    destination_arn = string
    role_arn        = optional(string)
    distribution    = optional(string, "ByLogStream")
  }))
  description = "Subscription filters keyed by a stable name, for shipping logs onward to Firehose, Lambda or OpenSearch."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the log group."
  default     = {}
}
