variable "name" {
  type        = string
  description = "Delivery stream name, unique within the account and region."
}

variable "role_arn" {
  type        = string
  description = "Role Firehose assumes to write to the destination and to its backup bucket. Build it with the iam-role module."
}

variable "s3_destination" {
  type = object({
    bucket_arn          = string
    prefix              = optional(string)
    error_output_prefix = optional(string)
    buffering_size      = optional(number, 64)
    buffering_interval  = optional(number, 300)
    compression_format  = optional(string, "GZIP")
    kms_key_arn         = optional(string)
  })
  description = "Deliver to S3. Set exactly one of this and http_endpoint_destination."
  default     = null

  validation {
    condition = var.s3_destination == null || contains(
      ["UNCOMPRESSED", "GZIP", "ZIP", "Snappy", "HADOOP_SNAPPY"],
      try(var.s3_destination.compression_format, "GZIP")
    )
    error_message = "The compression_format must be one Firehose supports."
  }
}

variable "http_endpoint_destination" {
  type = object({
    url                 = string
    name                = string
    access_key          = optional(string)
    buffering_size      = optional(number, 4)
    buffering_interval  = optional(number, 60)
    content_encoding    = optional(string, "GZIP")
    retry_duration      = optional(number, 300)
    common_attributes   = optional(map(string), {})
    backup_mode         = optional(string, "FailedDataOnly")
    backup_bucket_arn   = string
    backup_prefix       = optional(string)
    backup_error_prefix = optional(string)
  })
  description = "Deliver to an HTTP endpoint such as Datadog or New Relic, with an S3 bucket behind it. Set exactly one of this and s3_destination."
  default     = null
  sensitive   = true

  validation {
    condition     = var.http_endpoint_destination == null || startswith(try(var.http_endpoint_destination.url, "https://"), "https://")
    error_message = "The endpoint URL must be https. Firehose would otherwise carry the access key in the clear."
  }

  validation {
    condition = var.http_endpoint_destination == null || contains(
      ["FailedDataOnly", "AllData"],
      try(var.http_endpoint_destination.backup_mode, "FailedDataOnly")
    )
    error_message = "The backup_mode must be FailedDataOnly or AllData."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting records at rest inside the stream. Null uses the AWS-owned key."
  default     = null
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch log group Firehose writes delivery errors to. Null turns logging off, and a failing delivery then says nothing anywhere."
  default     = null
}

variable "log_stream_name" {
  type        = string
  description = "Log stream within that group."
  default     = "delivery"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
