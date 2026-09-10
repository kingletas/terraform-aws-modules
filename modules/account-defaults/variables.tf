variable "ebs_encryption_by_default" {
  type        = bool
  description = "Encrypt every new EBS volume in this region, whatever the resource that creates it asked for. It does not touch existing volumes."
  default     = true
}

variable "ebs_default_kms_key" {
  type = object({
    arn = string
  })
  description = "Key used when a volume is encrypted by default and names none. An object rather than a bare ARN, so a key created in the same plan can be passed in. Null uses the AWS-managed EBS key."
  default     = null
}

variable "block_s3_public_access" {
  type        = bool
  description = "Block public access to every bucket in the account, above whatever each bucket's own settings say."
  default     = true
}

variable "password_policy" {
  type = object({
    minimum_length        = optional(number, 14)
    require_lowercase     = optional(bool, true)
    require_uppercase     = optional(bool, true)
    require_numbers       = optional(bool, true)
    require_symbols       = optional(bool, true)
    allow_users_to_change = optional(bool, true)
    max_age_days          = optional(number, 0)
    reuse_prevention      = optional(number, 24)
    hard_expiry           = optional(bool, false)
  })
  description = <<-EOT
    IAM password policy for console users. Null leaves the account default,
    which is weaker than anything here.

    max_age_days defaults to 0, meaning no expiry. Forced rotation makes people
    pick worse passwords and is no longer recommended by NIST; length and a
    second factor do the work instead.
  EOT
  default     = {}
}

variable "default_security_group_vpc_ids" {
  type        = map(string)
  description = "VPCs whose default security group should be emptied, keyed by a stable name. A VPC created outside this library keeps its permissive default otherwise."
  default     = {}
}

variable "region_name" {
  type        = string
  description = "Region these settings apply to, for the output only. EBS encryption and the public access block are regional and account-wide respectively."
  default     = null
}
