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

variable "user_arns" {
  type        = list(string)
  description = "Principals allowed to encrypt and decrypt with the key."
  default     = []
}

variable "service_principals" {
  type        = list(string)
  description = "AWS service principals allowed to use the key, such as logs.us-east-1.amazonaws.com."
  default     = []
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
