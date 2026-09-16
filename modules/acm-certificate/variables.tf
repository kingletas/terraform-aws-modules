variable "domain_name" {
  type        = string
  description = "Primary domain the certificate covers."
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Extra domains on the same certificate. A wildcard such as *.example.com does not cover the apex."
  default     = []
}

variable "validation_method" {
  type        = string
  description = "DNS validates by a record and renews on its own. EMAIL needs somebody to click a link every renewal."
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "The validation_method must be DNS or EMAIL."
  }
}

variable "zone_id" {
  type        = string
  description = "Route 53 zone to write validation records into. Null skips them, leaving validation to be done elsewhere."
  default     = null

  validation {
    condition     = !var.create_validation_records || var.validation_method != "DNS" || var.zone_id != null
    error_message = "DNS validation records need a zone_id. Set create_validation_records = false to write them elsewhere."
  }
}

variable "create_validation_records" {
  type        = bool
  description = "Write the DNS validation records into zone_id. A bool rather than a null check on zone_id, because a zone created in the same plan is not known to exist until apply."
  default     = true
}

variable "wait_for_validation" {
  type        = bool
  description = "Block the apply until the certificate is issued, whether this module or someone else writes the validation records. Can take several minutes, and fails after 75 if the records never appear."
  default     = true
}

variable "key_algorithm" {
  type        = string
  description = "Key algorithm. EC_prime256v1 is smaller and faster than RSA_2048; some older clients only speak RSA."
  default     = "RSA_2048"
}

variable "certificate_transparency_logging" {
  type        = bool
  description = "Log issuance to public certificate transparency logs. Turning it off hides internal host names, and some browsers then reject the certificate."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the certificate."
  default     = {}
}
