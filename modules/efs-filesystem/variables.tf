variable "name" {
  type        = string
  description = "Name for the file system and the resources around it."
}

variable "subnet_ids" {
  type        = map(string)
  description = "Subnets to create mount targets in, keyed by availability zone. A client can only mount from a zone that has one. The vpc module's private_subnet_ids output has this shape."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required, or nothing can mount the file system."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups on the mount targets. They need NFS, TCP 2049, from the clients."
  default     = []
}

variable "performance_mode" {
  type        = string
  description = "generalPurpose has the lowest latency. maxIO scales further and cannot be changed later."
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "The performance_mode must be generalPurpose or maxIO."
  }
}

variable "throughput_mode" {
  type        = string
  description = "elastic bills for what you use. provisioned buys a fixed rate. bursting scales with stored size."
  default     = "elastic"

  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.throughput_mode)
    error_message = "The throughput_mode must be bursting, provisioned or elastic."
  }
}

variable "provisioned_throughput_in_mibps" {
  type        = number
  description = "Throughput to buy, in MiB/s. Only used when throughput_mode is provisioned."
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for encryption at rest. Null uses the AWS-managed EFS key."
  default     = null
}

variable "transition_to_ia_days" {
  type        = string
  description = "Move a file to infrequent access after this long untouched. Null keeps everything in standard storage."
  default     = "AFTER_30_DAYS"
}

variable "enable_backup" {
  type        = bool
  description = "Turn on the automatic daily backup EFS provides."
  default     = true
}

variable "access_points" {
  type = map(object({
    path           = string
    owner_uid      = optional(number, 1000)
    owner_gid      = optional(number, 1000)
    permissions    = optional(string, "0755")
    posix_uid      = optional(number, 1000)
    posix_gid      = optional(number, 1000)
    secondary_gids = optional(list(number), [])
  }))
  description = "Access points keyed by a stable name. Each pins a directory and a POSIX identity, so a client cannot read outside its own path."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
