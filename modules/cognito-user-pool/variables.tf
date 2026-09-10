variable "name" {
  type        = string
  description = "User pool name."
}

variable "domain_prefix" {
  type        = string
  description = "Prefix for the hosted UI domain, giving <prefix>.auth.<region>.amazoncognito.com. Null creates no hosted domain."
  default     = null
}

variable "custom_domain" {
  type        = string
  description = "Custom domain for the hosted UI. Needs an ACM certificate in us-east-1 and an A record afterwards."
  default     = null
}

variable "custom_domain_certificate_arn" {
  type        = string
  description = "ACM certificate for the custom domain, which must live in us-east-1."
  default     = null
}

variable "username_attributes" {
  type        = list(string)
  description = "Attributes usable as a username: email, phone_number, or both. Cannot be changed after creation."
  default     = ["email"]
}

variable "auto_verified_attributes" {
  type        = list(string)
  description = "Attributes Cognito verifies by sending a code."
  default     = ["email"]
}

variable "password_policy" {
  type = object({
    minimum_length                   = optional(number, 12)
    require_lowercase                = optional(bool, true)
    require_uppercase                = optional(bool, true)
    require_numbers                  = optional(bool, true)
    require_symbols                  = optional(bool, true)
    temporary_password_validity_days = optional(number, 3)
  })
  description = "Password rules. Length does more work than character classes, so raise the minimum before adding requirements."
  default     = {}
}

variable "mfa_configuration" {
  type        = string
  description = "OFF, ON to require it, or OPTIONAL to let users choose."
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "The mfa_configuration must be OFF, ON or OPTIONAL."
  }
}

variable "software_token_mfa" {
  type        = bool
  description = "Allow authenticator apps for the second factor. Preferred over SMS, which is interceptable."
  default     = true
}

variable "advanced_security_mode" {
  type        = string
  description = "Threat protection: OFF, AUDIT to record risk, or ENFORCED to act on it. Billed per active user."
  default     = "AUDIT"

  validation {
    condition     = contains(["OFF", "AUDIT", "ENFORCED"], var.advanced_security_mode)
    error_message = "The advanced_security_mode must be OFF, AUDIT or ENFORCED."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Refuse to delete the pool until this is turned off. Deleting a pool deletes every user in it."
  default     = true
}

variable "custom_attributes" {
  type = map(object({
    type       = optional(string, "String")
    mutable    = optional(bool, true)
    min_length = optional(number)
    max_length = optional(number)
  }))
  description = "Custom attributes keyed by name. These cannot be removed or retyped once the pool exists."
  default     = {}
}

variable "clients" {
  type = map(object({
    generate_secret               = optional(bool, false)
    callback_urls                 = optional(list(string), [])
    logout_urls                   = optional(list(string), [])
    allowed_oauth_flows           = optional(list(string), ["code"])
    allowed_oauth_scopes          = optional(list(string), ["openid", "email", "profile"])
    supported_identity_providers  = optional(list(string), ["COGNITO"])
    explicit_auth_flows           = optional(list(string), ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"])
    access_token_validity_minutes = optional(number, 60)
    id_token_validity_minutes     = optional(number, 60)
    refresh_token_validity_days   = optional(number, 30)
    prevent_user_existence_errors = optional(bool, true)
  }))
  description = "App clients keyed by name. generate_secret is for server-side clients only; a browser or mobile app cannot keep one."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the user pool."
  default     = {}
}
