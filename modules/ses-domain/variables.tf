variable "domain" {
  type        = string
  description = "Domain to send from, such as example.com. Verifying a domain lets you send as any address on it."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.domain))
    error_message = "The domain must be a hostname in lower case, with at least one dot."
  }
}

variable "dkim_key_length" {
  type        = string
  description = "Key length for Easy DKIM, where AWS holds the private key and rotates it."
  default     = "RSA_2048_BIT"

  validation {
    condition     = contains(["RSA_1024_BIT", "RSA_2048_BIT"], var.dkim_key_length)
    error_message = "The dkim_key_length must be RSA_1024_BIT or RSA_2048_BIT."
  }
}

variable "byodkim" {
  type = object({
    private_key = string
    selector    = string
  })
  description = "Sign with your own DKIM key instead of Easy DKIM. You then own the rotation, and AWS cannot do it for you."
  default     = null
  sensitive   = true
}

variable "mail_from_subdomain" {
  type        = string
  description = "Subdomain for the envelope sender, such as mail, giving mail.example.com. Null leaves the AWS default, which fails SPF alignment."
  default     = null

  validation {
    condition     = var.mail_from_subdomain == null || can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", coalesce(var.mail_from_subdomain, "mail")))
    error_message = "The mail_from_subdomain is a single label, such as mail, not a full domain."
  }
}

variable "behavior_on_mx_failure" {
  type        = string
  description = "What SES does when the custom MAIL FROM records cannot be read. REJECT_MESSAGE stops the send; USE_DEFAULT_VALUE falls back to the AWS domain and loses SPF alignment."
  default     = "USE_DEFAULT_VALUE"

  validation {
    condition     = contains(["USE_DEFAULT_VALUE", "REJECT_MESSAGE"], var.behavior_on_mx_failure)
    error_message = "The behavior_on_mx_failure must be USE_DEFAULT_VALUE or REJECT_MESSAGE."
  }
}

variable "tls_policy" {
  type        = string
  description = "REQUIRE bounces a message the receiving server will not take over TLS. OPTIONAL delivers it in the clear instead."
  default     = "REQUIRE"

  validation {
    condition     = contains(["REQUIRE", "OPTIONAL"], var.tls_policy)
    error_message = "The tls_policy must be REQUIRE or OPTIONAL."
  }
}

variable "suppressed_reasons" {
  type        = list(string)
  description = "Reasons an address is added to the account suppression list, so a repeat send to a known-bad address never leaves."
  default     = ["BOUNCE", "COMPLAINT"]

  validation {
    condition     = alltrue([for reason in var.suppressed_reasons : contains(["BOUNCE", "COMPLAINT"], reason)])
    error_message = "A suppression reason is BOUNCE or COMPLAINT."
  }
}

variable "event_destinations" {
  type = map(object({
    matching_event_types = list(string)
    enabled              = optional(bool, true)
    sns_topic_arn        = optional(string)
    cloudwatch_dimensions = optional(map(object({
      source        = optional(string, "MESSAGE_TAG")
      default_value = string
    })))
  }))
  description = "Where sending events go, keyed by a name you choose. Each destination sets exactly one of sns_topic_arn or cloudwatch_dimensions."
  default     = {}

  validation {
    condition = alltrue([
      for _, destination in var.event_destinations :
      (destination.sns_topic_arn == null) != (destination.cloudwatch_dimensions == null)
    ])
    error_message = "Each event destination sets exactly one of sns_topic_arn or cloudwatch_dimensions."
  }

  validation {
    condition = alltrue(flatten([
      for _, destination in var.event_destinations : [
        for event in destination.matching_event_types : contains([
          "SEND", "REJECT", "BOUNCE", "COMPLAINT", "DELIVERY", "OPEN", "CLICK",
          "RENDERING_FAILURE", "DELIVERY_DELAY", "SUBSCRIPTION",
        ], event)
      ]
    ]))
    error_message = "Each matching event type must be one SES publishes."
  }
}

variable "create_dns_records" {
  type        = bool
  description = "Publish the DKIM and MAIL FROM records into a Route 53 zone. False outputs them instead, for a zone run elsewhere."
  default     = false
}

variable "zone_id" {
  type        = string
  description = "Route 53 zone to publish records into. Required when create_dns_records is true."
  default     = null
}

variable "dmarc_policy" {
  type        = string
  description = "DMARC record value published at _dmarc. Null publishes none, which means no policy and no reports."
  default     = null
}

variable "create_smtp_user" {
  type        = bool
  description = "Create an IAM user and long-lived key for SMTP. Off, because an application that can call the SES API should use a role instead."
  default     = false
}

variable "smtp_user_name" {
  type        = string
  description = "Name for the SMTP user. Null names it after the domain."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
