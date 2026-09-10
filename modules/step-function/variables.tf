variable "name" {
  type        = string
  description = "State machine name, also used for the log group."
}

variable "definition_json" {
  type        = string
  description = "Amazon States Language definition. Render it with jsonencode or templatefile in the caller."
}

variable "role_arn" {
  type        = string
  description = "Role the state machine runs as. It needs permission for everything the states invoke."
}

variable "type" {
  type        = string
  description = "STANDARD keeps full history and is billed per transition. EXPRESS is cheaper at high volume, capped at five minutes, and keeps no history."
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXPRESS"], var.type)
    error_message = "The type must be STANDARD or EXPRESS."
  }
}

variable "log_level" {
  type        = string
  description = "ALL, ERROR, FATAL or OFF. An EXPRESS workflow keeps no execution history, so ALL is the only way to see what happened."
  default     = "ERROR"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.log_level)
    error_message = "The log_level must be ALL, ERROR, FATAL or OFF."
  }
}

variable "include_execution_data" {
  type        = bool
  description = "Include state input and output in logs. Convenient for debugging, and it writes your payloads to CloudWatch."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "Days to keep execution logs."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention period must be one of the values CloudWatch Logs accepts; seven years is 2557, not 2555."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the log group."
  default     = null
}

variable "tracing_enabled" {
  type        = bool
  description = "Trace executions with X-Ray."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
