variable "name" {
  type        = string
  description = "Bucket name. Must be globally unique across all of AWS."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.name))
    error_message = "The name must be 3-63 characters of lowercase letters, digits, hyphens or dots."
  }
}

variable "versioning_enabled" {
  type        = bool
  description = "Keep every version of an object. The only defence against an overwrite or a delete."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for server-side encryption. Null uses SSE-S3, which is free and still encryption at rest."
  default     = null
}

variable "bucket_key_enabled" {
  type        = bool
  description = "Use an S3 bucket key to cut KMS request costs on a busy bucket. Ignored without kms_key_arn."
  default     = true
}

variable "lifecycle_rules" {
  type = map(object({
    enabled                                = optional(bool, true)
    prefix                                 = optional(string)
    transition_days                        = optional(number)
    transition_storage_class               = optional(string, "STANDARD_IA")
    expiration_days                        = optional(number)
    noncurrent_version_expiration_days     = optional(number)
    abort_incomplete_multipart_upload_days = optional(number, 7)
  }))
  description = "Lifecycle rules keyed by a stable name. Each moves or expires objects on an age in days."
  default     = {}
}

variable "abort_incomplete_multipart_upload_days" {
  type        = number
  description = "Days before an unfinished multipart upload is discarded. These are billed as storage and are invisible in the console."
  default     = 7
}

variable "logging" {
  type = object({
    target_bucket = string
    target_prefix = optional(string, "s3-access-logs/")
  })
  description = "Where to write server access logs. Null disables access logging."
  default     = null
}

variable "policy_documents" {
  type        = list(string)
  description = "IAM policy documents in JSON, merged into the bucket policy this module writes. A bucket has one policy, so grants such as CloudFront or CloudTrail access go here rather than in a second aws_s3_bucket_policy. The Sid DenyInsecureTransport is reserved. Build this bucket's ARN from its name here, because the arn output waits for the policy and referencing it forms a cycle."
  default     = []
}

variable "force_destroy" {
  type        = bool
  description = "Let terraform destroy delete a bucket that still holds objects. Off, so a destroy fails loudly rather than deleting data."
  default     = false
}

variable "object_ownership" {
  type        = string
  description = "Object ownership. BucketOwnerEnforced disables ACLs entirely and is what you want unless something legacy needs them."
  default     = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "The object_ownership must be BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the bucket."
  default     = {}
}
