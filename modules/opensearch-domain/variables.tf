variable "name" {
  type        = string
  description = "Domain name. AWS caps this at 28 characters."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,27}$", var.name))
    error_message = "The name must be 3-28 characters, start with a lowercase letter, and hold only lowercase letters, digits and hyphens."
  }
}

variable "engine_version" {
  type        = string
  description = "Engine version, such as OpenSearch_2.17 or Elasticsearch_7.10."
  default     = "OpenSearch_2.17"
}

variable "instance_type" {
  type        = string
  description = "Data node instance type."
  default     = "t3.small.search"
}

variable "instance_count" {
  type        = number
  description = "Number of data nodes. Use a multiple of your availability zone count so shards spread evenly."
  default     = 2
}

variable "dedicated_master" {
  type = object({
    enabled        = optional(bool, false)
    instance_type  = optional(string, "t3.small.search")
    instance_count = optional(number, 3)
  })
  description = "Dedicated master nodes, which keep cluster management off the data nodes. Use three, never two."
  default     = {}
}

variable "zone_awareness_count" {
  type        = number
  description = "Availability zones to spread across. One disables zone awareness."
  default     = 2

  validation {
    condition     = contains([1, 2, 3], var.zone_awareness_count)
    error_message = "The zone_awareness_count must be 1, 2 or 3."
  }
}

variable "volume_size" {
  type        = number
  description = "EBS volume size per data node, in gibibytes."
  default     = 20
}

variable "volume_type" {
  type        = string
  description = "EBS volume type for data nodes."
  default     = "gp3"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets to place the domain in. Empty puts the domain on the public internet, which is almost never right."
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups for the domain's network interfaces."
  default     = []
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for encryption at rest. Null uses the AWS-managed OpenSearch key."
  default     = null
}

variable "master_user" {
  type = object({
    name     = string
    password = string
  })
  description = "Internal database master user, used when fine-grained access control is on. Prefer master_user_arn and IAM."
  default     = null
  sensitive   = true
}

variable "master_user_arn" {
  type        = string
  description = "IAM ARN acting as master user under fine-grained access control. Cannot be combined with master_user."
  default     = null
}

variable "access_policy_json" {
  type        = string
  description = "Domain access policy. Null leaves access to whatever fine-grained access control and the security groups allow."
  default     = null
}

variable "log_publishing" {
  type = map(object({
    cloudwatch_log_group_arn = string
    enabled                  = optional(bool, true)
  }))
  description = "Log publishing keyed by log type: INDEX_SLOW_LOGS, SEARCH_SLOW_LOGS, ES_APPLICATION_LOGS or AUDIT_LOGS."
  default     = {}
}

variable "auto_tune_enabled" {
  type        = bool
  description = "Let AWS adjust JVM and queue settings from observed load."
  default     = true
}

variable "off_peak_window_start_hour" {
  type        = number
  description = "Hour in UTC when the daily maintenance window opens."
  default     = 3
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the domain."
  default     = {}
}
