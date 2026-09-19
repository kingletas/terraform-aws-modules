variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the exchange."
  default     = "exchange"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "production"
}

variable "partners" {
  type = map(object({
    public_keys = map(string)
    read_only   = optional(bool, false)
  }))
  description = "Partners keyed by username, each with public keys keyed by a name you choose. Each partner is confined to its own prefix in the bucket."
}

variable "retention_days" {
  type        = number
  description = "Days a delivered file is kept before it expires. Partners re-send; auditors ask."
  default     = 365
}

variable "archive_after_days" {
  type        = number
  description = "Days before a file moves to infrequent access. Set to 0 to keep everything in standard storage."
  default     = 30
}

variable "notify_on_upload" {
  type        = bool
  description = "Alarm when a partner has not uploaded in a day. Only useful where a daily file is expected."
  default     = false
}

variable "alert_email" {
  type        = string
  description = "Address receiving alarm notifications. It must be confirmed by hand."
  default     = null
}
