variable "region" {
  type        = string
  description = "Region the trail and log groups live in. The trail records every region regardless."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the baseline."
  default     = "baseline"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "production"
}

variable "trail_retention_years" {
  type        = number
  description = "Years to keep CloudTrail log files in S3. Compliance regimes commonly ask for seven."
  default     = 7
}

variable "log_group_retention_days" {
  type        = number
  description = "Days to keep the queryable CloudTrail copy in CloudWatch Logs. Storage, not ingestion, so lowering it saves less than people expect."
  default     = 365
}

variable "is_organization_trail" {
  type        = bool
  description = "Record every account in the organization. Only valid from the management account."
  default     = false
}

variable "enable_vault_lock" {
  type        = bool
  description = "Make backup recovery points undeletable by anyone, including root. Read the warning in the README first."
  default     = false
}

variable "backup_selection_tag" {
  type = object({
    key   = string
    value = string
  })
  description = "Tag marking a resource for backup. Tag-based selection picks up new resources without an edit."
  default     = { key = "Backup", value = "true" }
}

variable "alert_email" {
  type        = string
  description = "Address receiving security notifications. It must be confirmed by hand."
  default     = null
}
