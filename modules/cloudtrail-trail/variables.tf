variable "name" {
  type        = string
  description = "Trail name."
}

variable "s3_bucket_name" {
  type        = string
  description = "Bucket receiving log files. Its policy must already allow the CloudTrail service to write."
}

variable "s3_key_prefix" {
  type        = string
  description = "Prefix inside the bucket."
  default     = null
}

variable "is_multi_region_trail" {
  type        = bool
  description = "Record events from every region. A single-region trail misses activity in the regions you are not watching, which is where it tends to happen."
  default     = true
}

variable "is_organization_trail" {
  type        = bool
  description = "Record every account in the organization. Only valid from the management account."
  default     = false
}

variable "include_global_service_events" {
  type        = bool
  description = "Include IAM, STS and CloudFront, which are global and otherwise recorded nowhere."
  default     = true
}

variable "enable_log_file_validation" {
  type        = bool
  description = "Write digest files so a tampered log can be detected. This is what makes the trail evidence."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting log files. The key policy must allow the CloudTrail service."
  default     = null
}

variable "cloudwatch_log_group_arn" {
  type        = string
  description = "Log group to also deliver events to, which is what makes them queryable and alarmable. Null skips it."
  default     = null
}

variable "cloudwatch_role_arn" {
  type        = string
  description = "Role CloudTrail uses to write to the log group. Required with cloudwatch_log_group_arn."
  default     = null
}

variable "sns_topic_name" {
  type        = string
  description = "SNS topic notified when a new log file arrives."
  default     = null
}

variable "data_events" {
  type = map(object({
    resource_type   = string
    resource_values = list(string)
    read_write_type = optional(string, "All")
  }))
  description = "Data event selectors keyed by a stable name, for object-level S3 or Lambda invocation logging. read_write_type is All, ReadOnly or WriteOnly. These are billed per event and a busy bucket generates a great many."
  default     = {}

  validation {
    condition     = alltrue([for _, selector in var.data_events : contains(["All", "ReadOnly", "WriteOnly"], selector.read_write_type)])
    error_message = "Each data event read_write_type must be All, ReadOnly or WriteOnly."
  }
}

variable "include_management_events" {
  type        = bool
  description = "Record management events, the control-plane calls that change the account. Turning this off leaves only the data events."
  default     = true
}

variable "management_events_read_write_type" {
  type        = string
  description = "Which management events to record: All, ReadOnly or WriteOnly."
  default     = "All"

  validation {
    condition     = contains(["All", "ReadOnly", "WriteOnly"], var.management_events_read_write_type)
    error_message = "The management_events_read_write_type must be All, ReadOnly or WriteOnly."
  }
}

variable "insight_types" {
  type        = list(string)
  description = "Insight types to detect unusual activity: ApiCallRateInsight, ApiErrorRateInsight."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the trail."
  default     = {}
}
