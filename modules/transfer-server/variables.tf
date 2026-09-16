variable "name" {
  type        = string
  description = "Name for the server and the resources around it."
}

variable "protocols" {
  type        = list(string)
  description = "Protocols served: SFTP, FTPS or FTP. Plain FTP is unencrypted and should never face the internet."
  default     = ["SFTP"]

  validation {
    condition     = alltrue([for protocol in var.protocols : contains(["SFTP", "FTPS", "FTP"], protocol)])
    error_message = "Each protocol must be SFTP, FTPS or FTP."
  }
}

variable "endpoint_type" {
  type        = string
  description = "PUBLIC is reachable from the internet. VPC places it in your subnets, where a security group can restrict it."
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.endpoint_type)
    error_message = "The endpoint_type must be PUBLIC or VPC."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC for a VPC endpoint type."
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for a VPC endpoint type."
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups for a VPC endpoint type."
  default     = []
}

variable "address_allocation_ids" {
  type        = list(string)
  description = "Elastic IP allocations, which give the server fixed addresses a partner can allow-list."
  default     = []
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate. Required when FTPS is in the protocol list."
  default     = null
}

variable "security_policy_name" {
  type        = string
  description = "Cryptographic policy governing which ciphers and key exchanges are offered."
  default     = "TransferSecurityPolicy-2025-03"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket users are given access to."
}

variable "users" {
  type = map(object({
    public_keys    = list(string)
    home_directory = optional(string)
    read_only      = optional(bool, false)
    posix_uid      = optional(number)
    posix_gid      = optional(number)
  }))
  description = "Users keyed by username. Each is confined to its home directory in the bucket, which defaults to a prefix named after the user, and cannot see anything above it."
  default     = {}

  validation {
    condition = alltrue([
      for username, user in var.users : user.home_directory == null || (trim(coalesce(user.home_directory, "-"), "/") != "" && !strcontains(coalesce(user.home_directory, "-"), ".."))
    ])
    error_message = "A home_directory must name a prefix below the bucket root and cannot contain \"..\"."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Days to keep transfer logs. These are the record of who moved which file."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention period must be one of the values CloudWatch Logs accepts; seven years is 2557, not 2555."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the log group."
  default     = null
}

variable "bucket_kms_key" {
  type = object({
    arn = string
  })
  description = "Customer-managed KMS key encrypting the bucket. Users are granted kms:Decrypt, and kms:GenerateDataKey when they can write, through S3 only. Null for a bucket using S3-managed keys."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
