variable "name" {
  type        = string
  description = "Name prefix. Instances are named name-01, name-02 and so on."
}

variable "instance_count" {
  type        = number
  description = "How many instances to launch."
  default     = 1

  validation {
    condition     = var.instance_count >= 0 && var.instance_count <= 99
    error_message = "The instance_count must be between 0 and 99."
  }
}

variable "ami_id" {
  type        = string
  description = "AMI to launch. Resolve this from a data source in the caller so the module never pins an image."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.small"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets to spread instances across, round-robin."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups attached to every instance."
  default     = []
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair for SSH access. Prefer Systems Manager Session Manager and leave this null."
  default     = null
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name. Required for Session Manager access."
  default     = null
}

variable "user_data" {
  type        = string
  description = "Cloud-init user data. Rendered by the caller, so the module holds no scripts."
  default     = null
  sensitive   = true
}

variable "user_data_replace_on_change" {
  type        = bool
  description = "Replace the instance when user data changes, rather than leaving a running instance that no longer matches its configuration."
  default     = true
}

variable "associate_public_ip_address" {
  type        = bool
  description = "Give each instance a public IP. Off by default; reach private instances through a NAT gateway or Session Manager."
  default     = false
}

variable "ebs_optimized" {
  type        = bool
  description = "Enable EBS optimization."
  default     = true
}

variable "monitoring" {
  type        = bool
  description = "Enable detailed CloudWatch monitoring at one-minute resolution."
  default     = true
}

variable "root_volume" {
  type = object({
    type                  = optional(string, "gp3")
    size                  = optional(number, 20)
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, true)
  })
  description = "Root EBS volume settings. Always encrypted."
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
  description = "Additional EBS volumes attached to every instance, keyed by a stable name."
  default     = {}
}

variable "kms_key_id" {
  type        = string
  description = "KMS key for EBS encryption. Defaults to the AWS-managed EBS key."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
