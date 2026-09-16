variable "name" {
  type        = string
  description = "Role name prefix."
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
  description = "OIDC providers allowed to assume the role, keyed by a stable name. Each must name the subject claim and the subjects it accepts; a GitHub subject must start with repo:<owner>/ and a literal owner."
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

  # A GitHub subject is recognised by its claim key or by the repo: prefix.
  validation {
    condition = alltrue(flatten([
      for key, provider in var.trusted_oidc_providers : [
        for subject in provider.subjects : can(regex("^repo:[A-Za-z0-9][A-Za-z0-9-]*/[^/]", subject))
      ] if strcontains(provider.subject_key, "token.actions.githubusercontent.com") || anytrue([for subject in provider.subjects : startswith(subject, "repo:")])
    ]))
    error_message = "A GitHub OIDC subject must start with repo:<owner>/ with a literal owner, such as repo:example-org/app:ref:refs/heads/main."
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
  description = "Inline policy documents keyed by policy name. These live and die with the role."
  default     = {}
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
