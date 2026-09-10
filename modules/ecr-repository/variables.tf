variable "name" {
  type        = string
  description = "Repository name. Slashes are allowed, so team/service works."
}

variable "image_tag_mutability" {
  type        = string
  description = "IMMUTABLE stops a tag being moved to a different image, which is what makes a deployed tag mean something."
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "The image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  type        = bool
  description = "Scan each pushed image for known vulnerabilities."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for encryption at rest. Null uses AES256, which is still encryption."
  default     = null
}

variable "force_delete" {
  type        = bool
  description = "Let terraform destroy delete a repository that still holds images."
  default     = false
}

variable "untagged_image_expiry_days" {
  type        = number
  description = "Expire untagged images after this many days. Set to 0 to keep them forever."
  default     = 14
}

variable "max_tagged_images" {
  type        = number
  description = "Keep at most this many tagged images. Set to 0 for no limit."
  default     = 50
}

variable "tag_prefixes_to_keep" {
  type        = list(string)
  description = "Tag prefixes the count limit applies to. Empty applies it to any tagged image."
  default     = []
}

variable "attach_policy" {
  type        = bool
  description = "Attach policy_json as a resource policy. A bool rather than a null check, because a policy naming a resource in the same plan is not known to exist until apply."
  default     = false
}

variable "policy_json" {
  type        = string
  description = "Repository policy, for granting pull access to another account."
  default     = null

  validation {
    condition     = !var.attach_policy || var.policy_json != null
    error_message = "attach_policy is true but no policy_json was given."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the repository."
  default     = {}
}
