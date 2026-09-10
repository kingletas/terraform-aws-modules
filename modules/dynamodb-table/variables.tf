variable "name" {
  type        = string
  description = "Table name."
}

variable "billing_mode" {
  type        = string
  description = "PAY_PER_REQUEST bills per read and write and needs no capacity planning. PROVISIONED is cheaper at steady high volume."
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "The billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "hash_key" {
  type        = string
  description = "Partition key attribute name. Cannot be changed without replacing the table."
}

variable "range_key" {
  type        = string
  description = "Sort key attribute name. Cannot be changed without replacing the table."
  default     = null
}

variable "attributes" {
  type = list(object({
    name = string
    type = string
  }))
  description = "Attributes used as a key anywhere, including in an index. Type is S, N or B. Attributes that are not keys are not declared here."

  validation {
    condition     = alltrue([for attribute in var.attributes : contains(["S", "N", "B"], attribute.type)])
    error_message = "Each attribute type must be S for string, N for number or B for binary."
  }
}

variable "read_capacity" {
  type        = number
  description = "Provisioned read units. Ignored unless billing_mode is PROVISIONED."
  default     = null
}

variable "write_capacity" {
  type        = number
  description = "Provisioned write units. Ignored unless billing_mode is PROVISIONED."
  default     = null
}

variable "global_secondary_indexes" {
  type = map(object({
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))
  description = "Global secondary indexes keyed by index name. Each is billed as its own table."
  default     = {}
}

variable "local_secondary_indexes" {
  type = map(object({
    range_key          = string
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
  }))
  description = "Local secondary indexes keyed by index name. These can only be created with the table."
  default     = {}
}

variable "ttl_attribute" {
  type        = string
  description = "Attribute holding an expiry timestamp in epoch seconds. Null disables time to live."
  default     = null
}

variable "stream_view_type" {
  type        = string
  description = "What a change event carries: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE or NEW_AND_OLD_IMAGES. Null disables the stream."
  default     = null
}

variable "point_in_time_recovery" {
  type        = bool
  description = "Keep 35 days of continuous backups, restorable to any second."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Refuse to delete the table until this is turned off."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key. Null uses the AWS-owned key, which is still encryption at rest."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the table."
  default     = {}
}
