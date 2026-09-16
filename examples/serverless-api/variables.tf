variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the API and everything under it."
  default     = "orders"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging and naming."
  default     = "production"
}

variable "stage_name" {
  type        = string
  description = "API Gateway stage, which becomes the first path segment."
  default     = "v1"
}

variable "lambda_bucket" {
  type        = string
  description = "Bucket holding the deployment archives."
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime for every function here."
  default     = "python3.13"
}

variable "functions" {
  type = map(object({
    s3_key      = string
    handler     = optional(string, "index.handler")
    memory_size = optional(number, 512)
    timeout     = optional(number, 30)
    environment = optional(map(string), {})

    http_path   = optional(string)
    http_method = optional(string, "POST")

    consumes_queue = optional(bool, false)
  }))
  description = "Functions keyed by name. One with an http_path gets an API route; one with consumes_queue is wired to the work queue instead."

  default = {
    create-order = {
      s3_key      = "create-order/v1.0.0.zip"
      http_path   = "orders"
      http_method = "POST"
    }
    process-order = {
      s3_key         = "process-order/v1.0.0.zip"
      consumes_queue = true
      timeout        = 120
    }
  }
}

variable "throttling_rate_limit" {
  type        = number
  description = "Steady-state requests per second across the stage."
  default     = 200
}

variable "manage_api_gateway_account_role" {
  type        = bool
  description = "Create the API Gateway CloudWatch logging role and set it on the account. Stage access logging fails without it; leave off where the account already has one."
  default     = false
}

variable "alert_email" {
  type        = string
  description = "Address receiving alarm notifications. It must be confirmed by hand."
  default     = null
}
