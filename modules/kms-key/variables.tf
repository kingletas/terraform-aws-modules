variable "name" {
  type        = string
  description = "Alias name, without the alias/ prefix."
}

variable "description" {
  type        = string
  description = "What this key encrypts."
}

variable "key_usage" {
  type        = string
  description = "ENCRYPT_DECRYPT for data, SIGN_VERIFY for signatures, GENERATE_VERIFY_MAC for message authentication."
  default     = "ENCRYPT_DECRYPT"
}

variable "customer_master_key_spec" {
  type        = string
  description = "Key algorithm. SYMMETRIC_DEFAULT is the usual choice; the RSA and ECC specs are for signing."
  default     = "SYMMETRIC_DEFAULT"
}

variable "multi_region" {
  type        = bool
  description = "Make the key replicable to other regions. Cannot be changed later."
  default     = false
}

variable "enable_key_rotation" {
  type        = bool
  description = "Rotate the backing key automatically. Only applies to symmetric keys."
  default     = true
}

variable "rotation_period_in_days" {
  type        = number
  description = "Days between automatic rotations, between 90 and 2560."
  default     = 365
}

variable "deletion_window_in_days" {
  type        = number
  description = "Days a scheduled deletion waits. This is the only window in which a deletion can be cancelled, so short is risky."
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "The deletion window must be between 7 and 30 days."
  }
}

variable "admin_arns" {
  type        = list(string)
  description = "Principals allowed to administer the key. Empty falls back to account root, which grants every IAM identity that has kms permissions."
  default     = []
}

variable "include_caller_as_admin" {
  type        = bool
  description = "Add the identity running Terraform to admin_arns, resolved to its role for an assumed-role session, so AWS does not refuse a policy that locks it out. The policy then changes with whoever applies; turn this off and list every administrator, including each identity that applies, for a stable policy."
  default     = true
}

variable "user_arns" {
  type        = list(string)
  description = "Principals allowed to encrypt and decrypt with the key."
  default     = []
}

variable "service_principals" {
  type        = list(string)
  description = "AWS service principals allowed to encrypt, decrypt and describe with the key, such as logs.us-east-1.amazonaws.com. Granted when the request comes from this account; a CloudWatch Logs principal only for log groups in this account."
  default     = []

  validation {
    condition     = alltrue([for principal in var.service_principals : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com(\\.cn)?$", principal))])
    error_message = "Each service principal must be a service principal such as logs.us-east-1.amazonaws.com."
  }
}

variable "delivery_service_principals" {
  type        = list(string)
  description = "AWS services that deliver to a resource encrypted with this key, such as cloudwatch.amazonaws.com for alarms or events.amazonaws.com for EventBridge publishing to an SNS topic. Granted kms:Decrypt and kms:GenerateDataKey* when the request comes from this account."
  default     = []

  validation {
    condition     = alltrue([for principal in var.delivery_service_principals : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com(\\.cn)?$", principal))])
    error_message = "Each delivery service principal must be a service principal such as events.amazonaws.com."
  }
}

variable "policy_json" {
  type        = string
  description = "A complete key policy, replacing the one this module builds. Use it when the generated policy is not enough."
  default     = null
}

variable "aliases" {
  type        = list(string)
  description = "Extra aliases, without the alias/ prefix."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the key."
  default     = {}
}
