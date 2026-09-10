variable "name" {
  type        = string
  description = "Name prefix for the launch template."
}

variable "description" {
  type        = string
  description = "What instances from this template are for."
  default     = null
}

variable "image_id" {
  type        = string
  description = "AMI to launch. Resolve it from a data source in the caller so the template never pins a stale image."
}

variable "instance_type" {
  type        = string
  description = "Default instance type. An autoscaling group with a mixed instances policy overrides this."
  default     = "t3.small"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair for SSH. Prefer Session Manager and leave this null."
  default     = null
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups applied to the primary network interface."
  default     = []
}

variable "iam_instance_profile_arn" {
  type        = string
  description = "IAM instance profile ARN. Needed for Session Manager and for anything calling AWS APIs."
  default     = null
}

variable "user_data" {
  type        = string
  description = "Cloud-init user data, unencoded. The module base64-encodes it."
  default     = null
  sensitive   = true
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Give instances a public IP. Off by default."
  default     = false
}

variable "root_volume" {
  type = object({
    device_name           = optional(string, "/dev/xvda")
    type                  = optional(string, "gp3")
    size                  = optional(number, 20)
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, true)
  })
  description = "Root volume settings. Always encrypted."
  default     = {}
}

variable "extra_volumes" {
  type = map(object({
    device_name           = string
    size                  = number
    type                  = optional(string, "gp3")
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, false)
  }))
  description = "Additional block devices keyed by a stable name."
  default     = {}
}

variable "kms_key_id" {
  type        = string
  description = "KMS key for EBS encryption. Null uses the AWS-managed EBS key."
  default     = null
}

variable "detailed_monitoring" {
  type        = bool
  description = "Enable one-minute CloudWatch monitoring."
  default     = true
}

variable "instance_requirements" {
  type = object({
    vcpu_min          = number
    vcpu_max          = number
    memory_mib_min    = number
    memory_mib_max    = number
    cpu_architectures = optional(list(string), ["x86_64"])
  })
  description = "Attribute-based instance selection, letting AWS pick any type that fits. Replaces instance_type when set."
  default     = null
}

variable "capacity_reservation_preference" {
  type        = string
  description = "Whether instances may use an open capacity reservation."
  default     = "open"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the template and to instances and volumes launched from it."
  default     = {}
}
