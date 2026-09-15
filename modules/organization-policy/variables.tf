variable "name" {
  type        = string
  description = "Policy name, unique within the organization."
}

variable "description" {
  type        = string
  description = "What the policy is for. This is what someone reads when a call is denied and they go looking for why."
}

variable "content" {
  type        = string
  description = "The policy document as JSON. A service control policy uses IAM policy syntax, so aws_iam_policy_document builds one."

  validation {
    condition     = can(jsondecode(var.content))
    error_message = "The content must be valid JSON."
  }
}

variable "type" {
  type        = string
  description = "Policy type. The organization must have this type enabled before a policy of it can exist."
  default     = "SERVICE_CONTROL_POLICY"

  validation {
    condition = contains([
      "SERVICE_CONTROL_POLICY",
      "RESOURCE_CONTROL_POLICY",
      "TAG_POLICY",
      "BACKUP_POLICY",
      "AISERVICES_OPT_OUT_POLICY",
      "CHATBOT_POLICY",
      "DECLARATIVE_POLICY_EC2",
      "SECURITYHUB_POLICY",
    ], var.type)
    error_message = "The type must be one AWS Organizations recognises."
  }
}

variable "targets" {
  type        = map(string)
  description = "What the policy attaches to, keyed by a name you choose, each value a root, organizational unit or account ID. Keying by name means detaching one target does not disturb the others."
  default     = {}

  validation {
    condition = alltrue([
      for _, id in var.targets :
      can(regex("^(r-[a-z0-9]{4,32}|ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}|[0-9]{12})$", id))
    ])
    error_message = "Each target must be a root ID, an organizational unit ID or a twelve-digit account ID."
  }
}

variable "skip_destroy" {
  type        = bool
  description = "Leave the policy in place when Terraform stops managing it, rather than deleting it."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
