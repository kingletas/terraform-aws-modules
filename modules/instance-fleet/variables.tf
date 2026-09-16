variable "name" {
  type        = string
  description = "Name prefix for the fleet. Every instance is named prefix-role or prefix-role-NN."
}

variable "defaults" {
  type = object({
    ami_id        = string
    instance_type = optional(string, "t3.medium")

    subnet_ids           = list(string)
    security_group_ids   = optional(list(string), [])
    key_name             = optional(string)
    iam_instance_profile = optional(string)

    associate_public_ip_address = optional(bool, false)
    ebs_optimized               = optional(bool, true)
    monitoring                  = optional(bool, true)
    source_dest_check           = optional(bool, true)

    root_volume_type       = optional(string, "gp3")
    root_volume_size       = optional(number, 30)
    root_volume_iops       = optional(number)
    root_volume_throughput = optional(number)

    kms_key_id = optional(string)
    user_data  = optional(string)
  })
  description = "Base specification every role starts from. A role overrides only what differs, which is what stops each one being a copy of the others."
}

variable "roles" {
  type = map(object({
    count = optional(number, 1)

    instance_type        = optional(string)
    subnet_ids           = optional(list(string))
    security_group_ids   = optional(list(string))
    key_name             = optional(string)
    iam_instance_profile = optional(string)
    ami_id               = optional(string)

    associate_public_ip_address = optional(bool)
    assign_elastic_ip           = optional(bool, false)
    source_dest_check           = optional(bool)
    monitoring                  = optional(bool)
    ebs_optimized               = optional(bool)

    root_volume_type       = optional(string)
    root_volume_size       = optional(number)
    root_volume_iops       = optional(number)
    root_volume_throughput = optional(number)

    kms_key_id = optional(string)
    user_data  = optional(string)

    extra_volumes = optional(map(object({
      device_name = string
      size        = number
      type        = optional(string, "gp3")
      iops        = optional(number)
      throughput  = optional(number)
    })), {})

    # Numbered by default, because a rename in Terraform is a destroy and a
    # create. Turn it off only for a role that will never have a second member.
    numbered = optional(bool, true)

    tags = optional(map(string), {})
  }))
  description = <<-EOT
    Roles in the fleet, keyed by role name. Each inherits from `defaults` and
    overrides only what differs.

    Instances are named `prefix-role-01` and upward. Numbering is on by default
    because a rename in Terraform destroys and recreates: without it, adding a
    second instance to a role replaces the first.

    Set `numbered = false` only for a role that will never have a second member
    and whose bare name something outside Terraform depends on.
  EOT

  validation {
    condition     = length(var.roles) > 0
    error_message = "A fleet needs at least one role."
  }

  validation {
    condition     = alltrue([for name, role in var.roles : role.count >= 0 && role.count <= 99])
    error_message = "Each role count must be between 0 and 99."
  }

  validation {
    condition = alltrue([
      for name, role in var.roles : can(regex("^[a-z][a-z0-9-]{0,20}$", name))
    ])
    error_message = "Each role name must be 1-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "instance_metadata_tags" {
  type        = bool
  description = "Expose instance tags through the metadata service. AWS then refuses any tag key outside letters, digits and + - = . , _ : @, which rules out spaces and slashes."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every instance, merged under each role's own tags."
  default     = {}
}
