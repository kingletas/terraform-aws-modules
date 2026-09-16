variable "name" {
  type        = string
  description = "Queue name. A FIFO queue gets the .fifo suffix added for you."
}

variable "fifo_queue" {
  type        = bool
  description = "Make this a FIFO queue: ordered, exactly-once, and lower throughput."
  default     = false
}

variable "content_based_deduplication" {
  type        = bool
  description = "Deduplicate FIFO messages on a hash of the body instead of an explicit deduplication ID."
  default     = false
}

variable "visibility_timeout_seconds" {
  type        = number
  description = "How long a received message is hidden from other consumers. Set it above your worst-case processing time or the message is delivered twice."
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "The visibility timeout must be between 0 and 43200 seconds."
  }
}

variable "message_retention_seconds" {
  type        = number
  description = "How long an unconsumed message survives before SQS drops it."
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "The retention period must be between 60 and 1209600 seconds."
  }
}

variable "receive_wait_time_seconds" {
  type        = number
  description = "Long-poll wait. Above zero cuts empty receives and the bill with them."
  default     = 20

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "The wait time must be between 0 and 20 seconds."
  }
}

variable "max_message_size" {
  type        = number
  description = "Largest message accepted, in bytes."
  default     = 262144
}

variable "delay_seconds" {
  type        = number
  description = "Delay before a new message becomes visible."
  default     = 0
}

variable "kms_key_id" {
  type        = string
  description = "KMS key for encryption at rest. Null uses the SQS-managed key, which is still encryption."
  default     = null
}

variable "dead_letter_queue" {
  type = object({
    enabled                   = optional(bool, true)
    max_receive_count         = optional(number, 5)
    message_retention_seconds = optional(number, 1209600)
  })
  description = "Dead letter queue for messages that keep failing. On by default, because without one a poison message is redelivered forever."
  default     = {}
}

variable "attach_policy" {
  type        = bool
  description = "Attach policy_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply."
  default     = false
}

variable "policy_json" {
  type        = string
  description = "Queue policy document. Null leaves the queue reachable only by IAM identities with explicit permission."
  default     = null

  validation {
    condition     = !var.attach_policy || var.policy_json != null
    error_message = "attach_policy is true but no policy_json was given."
  }
}

variable "sending_services" {
  type        = list(string)
  description = "Service principals allowed to send to the queue, such as cloudwatch.amazonaws.com, limited to this account by aws:SourceAccount. Merged into policy_json when attach_policy is on; the Sid AllowServiceSend is reserved."
  default     = []
}

variable "sending_source_arns" {
  type        = list(string)
  description = "Source ARNs the sending_services are further limited to, by aws:SourceArn. Empty allows any source in this account."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
