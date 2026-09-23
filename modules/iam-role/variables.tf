variable "name" {
  type        = string
  description = "Role name prefix, or the role's exact name when use_name_prefix is false. IAM allows 64 characters for a name and 38 for a prefix, which here includes the hyphen the module adds."

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]+$", var.name))
    error_message = "The name may use only letters, digits and + = , . @ _ -."
  }

  validation {
    condition     = var.use_name_prefix ? length(var.name) <= 37 : length(var.name) <= 64
    error_message = "The name is too long: 64 characters at most as an exact name, 37 as a prefix, because the module adds a hyphen and AWS adds a 26-character suffix."
  }
}

variable "use_name_prefix" {
  type        = bool
  description = "Treat name as a prefix AWS completes with a unique suffix. False names the role exactly name, which is what adopting an existing role needs, and gives up replacing it create-before-destroy."
  default     = true
}

variable "instance_profile_name" {
  type        = string
  description = "Exact name of the instance profile. Null follows the role: a prefix from name, or exactly name when use_name_prefix is false."
  default     = null

  validation {
    condition     = var.instance_profile_name == null || can(regex("^[A-Za-z0-9+=,.@_-]{1,128}$", var.instance_profile_name))
    error_message = "The instance profile name must be 1 to 128 letters, digits or + = , . @ _ -."
  }
}

variable "description" {
  type        = string
  description = "What this role is for."
  default     = null
}

variable "trusted_services" {
  type        = list(string)
  description = "AWS service principals allowed to assume the role, such as ec2.amazonaws.com."
  default     = []
}

variable "trusted_role_arns" {
  type        = list(string)
  description = "IAM role or account ARNs allowed to assume the role."
  default     = []
}

variable "trusted_oidc_providers" {
  type = map(object({
    provider_arn = string
    audience_key = string
    audiences    = list(string)
    subject_key  = string
    subjects     = list(string)
  }))
  description = "OIDC providers allowed to assume the role, keyed by a stable name. Each must name the subject claim and the subjects it accepts; a GitHub subject must open with an owner or repository claim whose value is a literal, such as repo:example-org/ or repository_owner_id:12345:."
  default     = {}

  validation {
    condition = alltrue([
      for key, provider in var.trusted_oidc_providers : length(provider.subjects) > 0 && trimspace(provider.subject_key) != ""
    ])
    error_message = "Each OIDC provider needs a subject_key and at least one subject, or any identity the issuer signs for can assume the role."
  }

  validation {
    condition = alltrue(flatten([
      for key, provider in var.trusted_oidc_providers : [
        for subject in provider.subjects : !can(regex("^[*?]*$", subject))
      ]
    ]))
    error_message = "An OIDC subject cannot be empty or made only of wildcards."
  }

  # IAM matches condition keys without regard to case, so GitHub is recognised case-insensitively on every field.
  validation {
    condition = alltrue(flatten([
      for key, provider in var.trusted_oidc_providers : [
        for subject in provider.subjects : can(regex("^(repo|repository|repository_id|repository_owner|repository_owner_id|job_workflow_ref):[^*?:/$]+([:/]|$)", subject))
        ] if anytrue(concat(
          [for field in [provider.provider_arn, provider.audience_key, provider.subject_key] : strcontains(lower(field), "token.actions.githubusercontent.com")],
          [for subject in provider.subjects : startswith(lower(subject), "repo:")],
      ))
    ]))
    error_message = "A GitHub OIDC subject must open with a claim that names one owner or repository, followed by a literal value with no wildcard, such as repo:example-org/app:ref:refs/heads/main or repository_owner_id:12345:repo:example-org/app:ref:refs/heads/main."
  }

  validation {
    condition = length(distinct([
      for key in keys(var.trusted_oidc_providers) : lower(replace(key, "/[^A-Za-z0-9]/", ""))
    ])) == length(var.trusted_oidc_providers)
    error_message = "OIDC provider keys must stay distinct once reduced to letters and digits, because each becomes a policy statement ID."
  }
}

variable "require_mfa" {
  type        = bool
  description = "Require multi-factor authentication on assume. Applies to the role and account principals only."
  default     = false
}

variable "external_id" {
  type        = string
  description = "External ID a third party must present on assume. The defence against the confused deputy problem."
  default     = null
}

variable "max_session_duration" {
  type        = number
  description = "Longest session in seconds, between one and twelve hours."
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "The session duration must be between 3600 and 43200 seconds."
  }
}

variable "managed_policy_arns" {
  type        = map(string)
  description = "Managed policies to attach, keyed by a stable name. The keys must be known at plan, so a policy created in the same configuration can be attached; its ARN need not be."
  default     = {}
}

variable "inline_policies" {
  type        = map(string)
  description = "Inline policy documents keyed by a stable name, which is also the policy's IAM name unless inline_policy_names gives another. These live and die with the role."
  default     = {}
}

variable "inline_policy_names" {
  type        = map(string)
  description = "IAM names for inline policies, keyed like inline_policies. Lets the key stay a literal a moved block can name while the IAM name carries the environment."
  default     = {}

  validation {
    condition     = length(setsubtract(keys(var.inline_policy_names), keys(var.inline_policies))) == 0
    error_message = format("inline_policy_names names a policy that inline_policies does not have: %s.", join(", ", sort(setsubtract(keys(var.inline_policy_names), keys(var.inline_policies)))))
  }
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Policy capping what this role can ever be granted, however its policies change later."
  default     = null
}

variable "create_instance_profile" {
  type        = bool
  description = "Also create an instance profile, which is how an EC2 instance is given the role."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
