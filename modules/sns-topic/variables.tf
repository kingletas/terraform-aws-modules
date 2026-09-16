variable "name" {
  type        = string
  description = "Topic name. A FIFO topic gets the .fifo suffix added for you."
}

variable "display_name" {
  type        = string
  description = "Name shown as the sender on SMS and email deliveries."
  default     = null
}

variable "fifo_topic" {
  type        = bool
  description = "Make this a FIFO topic. Only FIFO queues may subscribe."
  default     = false
}

variable "content_based_deduplication" {
  type        = bool
  description = "Deduplicate FIFO messages on a hash of the body. Ignored for a standard topic."
  default     = false
}

variable "kms_key_id" {
  type        = string
  description = "KMS key for encryption at rest. Null leaves the topic unencrypted, which SNS allows and an audit will not."
  default     = null
}

variable "subscriptions" {
  type = map(object({
    protocol               = string
    endpoint               = string
    raw_message_delivery   = optional(bool, false)
    filter_policy          = optional(string)
    filter_policy_scope    = optional(string)
    endpoint_auto_confirms = optional(bool, false)
  }))
  description = "Subscriptions keyed by a stable name. Email and SMS endpoints must be confirmed by their owner before they deliver."
  default     = {}
}

variable "delivery_policy_json" {
  type        = string
  description = "Delivery retry policy as JSON. Null uses the SNS defaults."
  default     = null
}

variable "attach_policy" {
  type        = bool
  description = "Attach policy_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply."
  default     = false
}

variable "policy_json" {
  type        = string
  description = "Topic policy document. Null leaves publishing to IAM identities with explicit permission."
  default     = null

  validation {
    condition     = !var.attach_policy || var.policy_json != null
    error_message = "attach_policy is true but no policy_json was given."
  }
}

variable "publishing_services" {
  type        = list(string)
  description = "Service principals allowed to publish to the topic, such as cloudwatch.amazonaws.com, limited to this account by aws:SourceAccount or aws:SourceOwner, whichever the service sends. Merged into policy_json when attach_policy is on; the Sids AllowServicePublishBySourceAccount and AllowServicePublishBySourceOwner are reserved."
  default     = []
}

variable "publishing_source_arns" {
  type        = list(string)
  description = "Source ARNs the publishing_services are further limited to, by aws:SourceArn. Empty allows any source in this account."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the topic."
  default     = {}
}
