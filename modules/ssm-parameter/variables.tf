variable "parameters" {
  type = map(object({
    type            = optional(string, "String")
    description     = optional(string)
    tier            = optional(string, "Standard")
    data_type       = optional(string, "text")
    allowed_pattern = optional(string)
  }))
  description = "Parameters keyed by full path, such as /prod/api/log-level. This carries the shape; the values go in `values`."

  validation {
    condition = alltrue([
      for path, parameter in var.parameters : contains(["String", "StringList", "SecureString"], parameter.type)
    ])
    error_message = "Each parameter type must be String, StringList or SecureString."
  }

  validation {
    condition     = alltrue([for path, parameter in var.parameters : startswith(path, "/")])
    error_message = "Each parameter name must be a path starting with a slash."
  }
}

variable "values" {
  type        = map(string)
  description = "Parameter values, keyed by the same paths as `parameters`. Kept separate so the map itself can be marked sensitive without making every path a secret."
  sensitive   = true

  validation {
    condition     = alltrue([for path in keys(var.parameters) : contains(keys(nonsensitive(var.values)), path)])
    error_message = format("No value was given for: %s.", join(", ", [for path in keys(var.parameters) : path if !contains(keys(nonsensitive(var.values)), path)]))
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting SecureString parameters. Null uses the AWS-managed SSM key."
  default     = null
}

variable "overwrite_existing" {
  type        = bool
  description = "Take ownership of a parameter that already exists rather than failing."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every parameter."
  default     = {}
}
