variable "name" {
  type        = string
  description = "Function name, also used for the log group."
}

variable "description" {
  type        = string
  description = "What this function does."
  default     = null
}

variable "package_type" {
  type        = string
  description = "Zip for a code archive, Image for a container image from ECR."
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "The package_type must be Zip or Image."
  }
}

variable "filename" {
  type        = string
  description = "Local path to a deployment archive. Use this or s3_bucket, or image_uri for a container."
  default     = null
}

variable "source_code_hash" {
  type        = string
  description = "Base64 SHA-256 of the archive. Without it Terraform cannot tell that the code changed."
  default     = null
}

variable "s3_bucket" {
  type        = string
  description = "Bucket holding the deployment archive."
  default     = null
}

variable "s3_key" {
  type        = string
  description = "Key of the deployment archive."
  default     = null
}

variable "s3_object_version" {
  type        = string
  description = "Version of the archive object, so a deploy pins an exact build."
  default     = null
}

variable "image_uri" {
  type        = string
  description = "ECR image URI. Required when package_type is Image."
  default     = null
}

variable "handler" {
  type        = string
  description = "Entry point, such as index.handler. Required for a Zip package."
  default     = null
}

variable "runtime" {
  type        = string
  description = "Runtime, such as python3.13 or nodejs22.x. Required for a Zip package."
  default     = null
}

variable "architecture" {
  type        = string
  description = "arm64 is cheaper per millisecond than x86_64 and is the better default unless a dependency needs otherwise."
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "The architecture must be arm64 or x86_64."
  }
}

variable "role_arn" {
  type        = string
  description = "Execution role. It needs permission to write to its own log group at the very least."
}

variable "memory_size" {
  type        = number
  description = "Memory in mebibytes. CPU is allocated in proportion, so more memory often costs less overall."
  default     = 512

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "The memory size must be between 128 and 10240 MiB."
  }
}

variable "timeout" {
  type        = number
  description = "Seconds before the function is killed. Behind an API Gateway, a value above 29 cannot be reached anyway."
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "The timeout must be between 1 and 900 seconds."
  }
}

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables. Anything secret belongs in Secrets Manager, read at runtime."
  default     = {}
  sensitive   = true
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting environment variables at rest and the log group."
  default     = null
}

variable "vpc_config" {
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  description = "Run the function inside a VPC. It then reaches the internet only through a NAT gateway or VPC endpoints."
  default     = null
}

variable "layers" {
  type        = list(string)
  description = "Layer ARNs to attach, at most five."
  default     = []
}

variable "reserved_concurrent_executions" {
  type        = number
  description = "Cap on concurrent executions, which also reserves them. Set to -1 for no cap."
  default     = -1
}

variable "provisioned_concurrency" {
  type        = number
  description = "Pre-warmed execution environments on the published version, removing cold starts. Billed whether used or not. Zero disables it."
  default     = 0
}

variable "publish" {
  type        = bool
  description = "Publish a numbered version on each change, which is what an alias and provisioned concurrency point at."
  default     = false
}

variable "dead_letter_target_arn" {
  type        = string
  description = "SQS queue or SNS topic receiving asynchronous invocations that exhausted their retries."
  default     = null
}

variable "tracing_mode" {
  type        = string
  description = "X-Ray tracing: PassThrough follows an existing trace, Active starts one."
  default     = "Active"

  validation {
    condition     = contains(["PassThrough", "Active"], var.tracing_mode)
    error_message = "The tracing_mode must be PassThrough or Active."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Days to keep logs. Without a managed log group, Lambda creates one that never expires."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention period must be one of the values CloudWatch Logs accepts; seven years is 2557, not 2555."
  }
}

variable "event_source_mappings" {
  type = map(object({
    event_source_arn                   = string
    batch_size                         = optional(number, 10)
    maximum_batching_window_in_seconds = optional(number)
    starting_position                  = optional(string)
    function_response_types            = optional(list(string), [])
    maximum_retry_attempts             = optional(number)
    enabled                            = optional(bool, true)
  }))
  description = "Pull-based event sources keyed by a stable name: SQS, Kinesis, DynamoDB streams."
  default     = {}
}

variable "allowed_invoke_principals" {
  type = map(object({
    principal  = string
    source_arn = optional(string)
  }))
  description = "Services allowed to invoke the function, keyed by a stable name. Always set source_arn, or any caller of that service can invoke it."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
