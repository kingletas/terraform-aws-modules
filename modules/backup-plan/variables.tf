variable "name" {
  type        = string
  description = "Name for the plan, the vault and the role."
}

variable "vault_kms_key_arn" {
  type        = string
  description = "KMS key encrypting the vault. Null uses the AWS-managed Backup key."
  default     = null
}

variable "vault_lock" {
  type = object({
    changeable_for_days = optional(number, 3)
    min_retention_days  = optional(number, 7)
    max_retention_days  = optional(number)
  })
  description = "Vault Lock in compliance mode, which makes recovery points undeletable by anyone including root. Read the note in the README before turning this on."
  default     = null
}

variable "rules" {
  type = map(object({
    schedule                  = string
    start_window_minutes      = optional(number, 60)
    completion_window_minutes = optional(number, 480)
    delete_after_days         = optional(number, 35)
    cold_storage_after_days   = optional(number)
    enable_continuous_backup  = optional(bool, false)
    recovery_point_tags       = optional(map(string), {})

    copy_to_vault_arn      = optional(string)
    copy_delete_after_days = optional(number)
  }))
  description = "Backup rules keyed by rule name. The schedule is a cron expression in UTC."

  validation {
    condition     = length(var.rules) > 0
    error_message = "A plan with no rules backs nothing up."
  }
}

variable "selection_tags" {
  type = map(object({
    key   = string
    value = string
    type  = optional(string, "STRINGEQUALS")
  }))
  description = "Tag conditions selecting which resources are backed up, keyed by a stable name. Tag-based selection picks up new resources on its own."
  default     = {}
}

variable "selection_resource_arns" {
  type        = list(string)
  description = "Resource ARNs to back up explicitly, in addition to anything the tags select."
  default     = []
}

variable "not_resources" {
  type        = list(string)
  description = "Resource ARNs to exclude even when a tag selects them."
  default     = []
}

variable "notifications" {
  type = object({
    sns_topic_arn = string
    events        = optional(list(string), ["BACKUP_JOB_FAILED", "COPY_JOB_FAILED", "RESTORE_JOB_FAILED"])
  })
  description = "Where to send job events. The default set is failures only, because a message on every success is noise."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
