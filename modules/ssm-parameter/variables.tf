variable "path_prefix" {
  type        = string
  description = "Path every parameter hangs under, such as /prod/api. Empty puts them at the root of the hierarchy."
  default     = ""

  validation {
    condition     = var.path_prefix == "" || (startswith(var.path_prefix, "/") && !endswith(var.path_prefix, "/"))
    error_message = "The path prefix must be empty, or start with a slash and not end with one."
  }
}

variable "parameters" {
  type = map(object({
    type            = optional(string, "String")
    description     = optional(string)
    tier            = optional(string, "Standard")
    data_type       = optional(string, "text")
    allowed_pattern = optional(string)
  }))
  description = "Parameters keyed by a short name under `path_prefix`, such as log-level or api/webhook-key. The key is the address a `moved` block names, so keep it a literal you write rather than a value you compute. This carries the shape; the values go in `values`."

  validation {
    condition = alltrue([
      for name, parameter in var.parameters : contains(["String", "StringList", "SecureString"], parameter.type)
    ])
    error_message = "Each parameter type must be String, StringList or SecureString."
  }

  validation {
    condition     = alltrue([for name in keys(var.parameters) : name != "" && !startswith(name, "/") && !endswith(name, "/")])
    error_message = "Each parameter name is relative to the path prefix, so it may not be empty, start with a slash or end with one."
  }
}

variable "values" {
  type        = map(string)
  description = "Parameter values, keyed by the same names as `parameters`. Kept separate so the map itself can be marked sensitive without making every name a secret."
  sensitive   = true

  validation {
    condition     = alltrue([for name in keys(var.parameters) : contains(keys(nonsensitive(var.values)), name)])
    error_message = format("No value was given for: %s.", join(", ", [for name in keys(var.parameters) : name if !contains(keys(nonsensitive(var.values)), name)]))
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
