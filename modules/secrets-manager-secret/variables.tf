variable "name" {
  type        = string
  description = "Secret name. A path such as prod/api/database groups related secrets."
}

variable "description" {
  type        = string
  description = "What this secret holds. Never put the value here."
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the secret. Null uses the AWS-managed Secrets Manager key."
  default     = null
}

variable "initial_value" {
  type        = string
  description = "First version of the secret. Anything set here lands in Terraform state in clear text; prefer generate_password or writing the value out of band."
  default     = null
  sensitive   = true
}

variable "initial_json" {
  type        = map(string)
  description = "First version as a JSON object. Same warning as initial_value: it reaches state."
  default     = null
  sensitive   = true
}

variable "generate_password" {
  type        = bool
  description = "Generate a random password as the first version. It still reaches state, but nobody has to handle it."
  default     = false
}

variable "password_length" {
  type        = number
  description = "Length of the generated password."
  default     = 32
}

variable "password_override_special" {
  type        = string
  description = "Special characters the generated password may use. Trim it to what the consuming system actually accepts."
  default     = "!#$%&*()-_=+[]{}<>:?"
}

variable "recovery_window_in_days" {
  type        = number
  description = "Days a deleted secret can be restored. Zero deletes immediately and cannot be undone."
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "The recovery window must be 0, or between 7 and 30 days."
  }
}

variable "rotation" {
  type = object({
    lambda_arn               = string
    automatically_after_days = optional(number, 30)
    duration                 = optional(string)
  })
  description = "Automatic rotation. Needs a rotation Lambda that knows how to change the credential at both ends."
  default     = null
}

variable "replica_regions" {
  type = map(object({
    kms_key_id = optional(string)
  }))
  description = "Regions to replicate the secret to, keyed by region name."
  default     = {}
}

variable "attach_policy" {
  type        = bool
  description = "Attach policy_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply."
  default     = false
}

variable "policy_json" {
  type        = string
  description = "Resource policy on the secret, for cross-account access."
  default     = null

  validation {
    condition     = !var.attach_policy || var.policy_json != null
    error_message = "attach_policy is true but no policy_json was given."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the secret."
  default     = {}
}
