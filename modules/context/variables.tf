variable "project" {
  type        = string
  description = "What this infrastructure is for, such as storefront or warehouse."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "The project must be 2-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Which environment this is. The value decides sizing defaults and whether production guards apply."

  validation {
    condition     = contains(["dev", "staging", "uat", "production"], var.environment)
    error_message = "The environment must be dev, staging, uat or production."
  }
}

variable "owner" {
  type        = string
  description = "Team answerable for this infrastructure. Appears on every resource and is what a cost report groups by."
}

variable "component" {
  type        = string
  description = "Optional component within the project, such as web or data. Becomes part of the name."
  default     = null
}

variable "extra_tags" {
  type        = map(string)
  description = "Tags merged on top of the generated ones. A key that collides wins."
  default     = {}
}

variable "cost_centre" {
  type        = string
  description = "Cost centre or budget code, for chargeback."
  default     = null
}
