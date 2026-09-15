variable "create_organization" {
  type        = bool
  description = "Create the organization. Set false in an account where one already exists, and the module reads it instead of trying to create a second."
  default     = true
}

variable "feature_set" {
  type        = string
  description = "ALL gives policies and trusted service access. CONSOLIDATED_BILLING gives a shared bill and nothing else."
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.feature_set)
    error_message = "The feature_set must be ALL or CONSOLIDATED_BILLING."
  }
}

variable "aws_service_access_principals" {
  type        = list(string)
  description = "Service principals allowed to operate across the organization, such as cloudtrail.amazonaws.com or sso.amazonaws.com. A service reaches member accounts only once it is listed here."
  default     = []
}

variable "enabled_policy_types" {
  type        = list(string)
  description = "Policy types the organization may attach. Service control policies are on by default; the others cost nothing until a policy exists."
  default     = ["SERVICE_CONTROL_POLICY"]

  validation {
    condition = alltrue([
      for type in var.enabled_policy_types : contains([
        "SERVICE_CONTROL_POLICY",
        "RESOURCE_CONTROL_POLICY",
        "TAG_POLICY",
        "BACKUP_POLICY",
        "AISERVICES_OPT_OUT_POLICY",
        "CHATBOT_POLICY",
        "DECLARATIVE_POLICY_EC2",
        "SECURITYHUB_POLICY",
      ], type)
    ])
    error_message = "Each policy type must be one AWS Organizations recognises."
  }
}

variable "organizational_units" {
  type = map(object({
    tags = optional(map(string), {})
    children = optional(map(object({
      tags = optional(map(string), {})
    })), {})
  }))
  description = "Organizational units below the root, keyed by name, each with an optional map of children. Two levels, which is what most organisations use; AWS allows five."
  default     = {}

  validation {
    condition     = alltrue([for name, _ in var.organizational_units : !strcontains(name, "/")])
    error_message = "An organizational unit name may not contain a slash, which this module uses to address a child as parent/child."
  }

  validation {
    condition = alltrue(flatten([
      for _, unit in var.organizational_units : [
        for name, _ in unit.children : !strcontains(name, "/")
      ]
    ]))
    error_message = "An organizational unit name may not contain a slash, which this module uses to address a child as parent/child."
  }
}

variable "accounts" {
  type = map(object({
    name                       = string
    email                      = string
    parent                     = optional(string)
    role_name                  = optional(string, "OrganizationAccountAccessRole")
    iam_user_access_to_billing = optional(string, "ALLOW")
    close_on_deletion          = optional(bool, false)
    tags                       = optional(map(string), {})
  }))
  description = "Member accounts to create, keyed by a stable name. parent is an organizational unit key, either top or parent/child; null places the account at the root."
  default     = {}

  validation {
    condition     = alltrue([for _, account in var.accounts : strcontains(account.email, "@")])
    error_message = "Every account needs an email address, and it must be one no other AWS account already uses."
  }

  validation {
    condition = alltrue([
      for _, account in var.accounts :
      contains(["ALLOW", "DENY"], account.iam_user_access_to_billing)
    ])
    error_message = "The iam_user_access_to_billing must be ALLOW or DENY."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
