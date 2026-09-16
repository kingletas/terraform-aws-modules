variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the pipeline."
  default     = "warehouse"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "production"
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR for the pipeline VPC."
  default     = "10.60.0.0/16"
}

variable "sources" {
  type = map(object({
    engine      = string
    server_name = string
    port        = number
    database    = string
    username    = string
    description = optional(string)
  }))
  description = "Source systems to ingest from, keyed by name. Each run passes the name, engine, server_name, port, database and the credentials secret ARN to the extraction. Passwords are not here; each source gets a secret you populate out of band."
  default     = {}
}

variable "extract_schedule" {
  type        = string
  description = "Cron expression, in UTC, for the extraction run."
  default     = "cron(0 4 * * ? *)"
}

variable "transform_schedule" {
  type        = string
  description = "Cron expression, in UTC, for the transform run. Leave room after extraction finishes."
  default     = "cron(0 6 * * ? *)"
}

variable "raw_retention_days" {
  type        = number
  description = "Days a raw extract is kept. Long enough to reprocess without re-extracting from the source."
  default     = 90
}

variable "curated_retention_days" {
  type        = number
  description = "Days a curated dataset is kept before expiring. Zero keeps it forever."
  default     = 0
}

variable "alert_email" {
  type        = string
  description = "Address receiving alarm notifications. It must be confirmed by hand."
  default     = null
}
