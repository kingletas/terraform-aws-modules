variable "name" {
  type        = string
  description = "Key pair name in EC2."
}

variable "public_key" {
  type        = string
  description = "An existing public key to register. Leave null to generate a new pair, which puts the private key in Terraform state."
  default     = null
}

variable "algorithm" {
  type        = string
  description = "Algorithm for a generated key. ED25519 is smaller and faster; RSA is what older tooling still expects."
  default     = "ED25519"

  validation {
    condition     = contains(["ED25519", "RSA"], var.algorithm)
    error_message = "The algorithm must be ED25519 or RSA."
  }
}

variable "rsa_bits" {
  type        = number
  description = "Key size for RSA. Ignored for ED25519."
  default     = 4096

  validation {
    condition     = var.rsa_bits >= 2048
    error_message = "An RSA key must be at least 2048 bits."
  }
}

variable "write_private_key_to" {
  type        = string
  description = <<-EOT
    Path to write a generated private key to, at mode 0600. Null writes nothing.

    Writing it makes the key usable immediately and puts a credential on the
    disk of whoever ran the apply. Prefer null, and read the key out of the
    secret below.
  EOT
  default     = null
}

variable "store_in_secrets_manager" {
  type        = bool
  description = "Also store a generated private key in Secrets Manager, which is where a CI job or another operator can reach it."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the secret. Null uses the AWS-managed Secrets Manager key."
  default     = null
}

variable "recovery_window_in_days" {
  type        = number
  description = "Days a deleted secret can be restored. Zero deletes immediately, which frees the name for reuse."
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
