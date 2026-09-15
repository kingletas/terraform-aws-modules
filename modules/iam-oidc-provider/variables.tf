variable "url" {
  type        = string
  description = "Issuer URL, such as https://token.actions.githubusercontent.com. It must match the iss claim in the token exactly, with no trailing slash."

  validation {
    condition     = startswith(var.url, "https://")
    error_message = "The issuer URL must begin with https://."
  }

  validation {
    condition     = !endswith(var.url, "/")
    error_message = "The issuer URL must not end with a slash, because it is compared to the iss claim character for character."
  }
}

variable "client_ids" {
  type        = list(string)
  description = "Audiences the provider may issue for, which is the aud claim. GitHub Actions uses sts.amazonaws.com."

  validation {
    condition     = length(var.client_ids) > 0
    error_message = "At least one client ID is required, or no token can ever be accepted."
  }
}

variable "thumbprints" {
  type        = list(string)
  description = "SHA-1 thumbprints of the issuer's certificate chain. Leave null for a provider AWS verifies against its own trust store, which includes GitHub and GitLab."
  default     = null

  validation {
    condition = var.thumbprints == null || alltrue([
      for thumbprint in coalesce(var.thumbprints, []) : can(regex("^[0-9a-fA-F]{40}$", thumbprint))
    ])
    error_message = "A thumbprint is 40 hexadecimal characters."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
