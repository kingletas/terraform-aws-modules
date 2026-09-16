variable "name" {
  type        = string
  description = "API name."
}

variable "description" {
  type        = string
  description = "What this API serves."
  default     = null
}

variable "openapi_body" {
  type        = string
  description = "OpenAPI document defining the whole API. Set this, or define routes instead."
  default     = null
}

variable "routes" {
  type = map(object({
    path                    = string
    method                  = string
    authorization           = string
    authorizer_key          = optional(string)
    api_key_required        = optional(bool, false)
    lambda_invoke_arn       = optional(string)
    integration_type        = optional(string, "AWS_PROXY")
    integration_uri         = optional(string)
    integration_http_method = optional(string, "POST")
    request_parameters      = optional(map(bool), {})
  }))
  description = "Routes keyed by a stable name. A path such as /orders/{id} may be up to six segments deep, and / is the API root. Every route states its authorization, so a public route is a choice rather than a default. Ignored when openapi_body is set."
  default     = {}

  validation {
    condition = alltrue([
      for key, route in var.routes : contains(["NONE", "AWS_IAM", "CUSTOM", "COGNITO_USER_POOLS"], route.authorization)
    ])
    error_message = "Each route's authorization must be NONE, AWS_IAM, CUSTOM or COGNITO_USER_POOLS."
  }

  validation {
    condition = alltrue([
      for key, route in var.routes : can(regex("^/?$|^/?[^/]+(/[^/]+){0,5}/?$", route.path))
    ])
    error_message = "Each route path must be / or up to six non-empty segments separated by single slashes, such as /orders/{id}."
  }

  validation {
    condition = alltrue([
      for key, route in var.routes : route.integration_type == "MOCK" || route.lambda_invoke_arn != null || route.integration_uri != null
    ])
    error_message = "Every route except a MOCK integration needs lambda_invoke_arn or integration_uri."
  }
}

variable "authorizers" {
  type = map(object({
    type                   = optional(string, "COGNITO_USER_POOLS")
    provider_arns          = optional(list(string), [])
    identity_source        = optional(string, "method.request.header.Authorization")
    authorizer_uri         = optional(string)
    authorizer_credentials = optional(string)
    result_ttl_seconds     = optional(number, 300)
  }))
  description = "Authorizers keyed by a stable name, referenced by a route's authorizer_key."
  default     = {}
}

variable "endpoint_type" {
  type        = string
  description = "REGIONAL for most APIs, PRIVATE for one reachable only through a VPC endpoint, EDGE to front it with CloudFront."
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "PRIVATE", "EDGE"], var.endpoint_type)
    error_message = "The endpoint_type must be REGIONAL, PRIVATE or EDGE."
  }
}

variable "vpc_endpoint_ids" {
  type        = list(string)
  description = "VPC endpoints allowed to reach a PRIVATE API."
  default     = []
}

variable "stage_name" {
  type        = string
  description = "Stage to deploy to, which becomes the first path segment of the invoke URL."
  default     = "v1"
}

variable "throttling_rate_limit" {
  type        = number
  description = "Steady-state requests per second across the stage. Minus one leaves it unlimited, which is a bill with no ceiling."
  default     = 100
}

variable "throttling_burst_limit" {
  type        = number
  description = "Burst capacity above the steady rate."
  default     = 200
}

variable "log_retention_days" {
  type        = number
  description = "Days to keep access logs."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention period must be one of the values CloudWatch Logs accepts; seven years is 2557, not 2555."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the access log group."
  default     = null
}

variable "xray_tracing_enabled" {
  type        = bool
  description = "Trace requests through to the integration with X-Ray."
  default     = true
}

variable "metrics_enabled" {
  type        = bool
  description = "Publish per-method CloudWatch metrics. Useful, and billed as custom metrics."
  default     = true
}

variable "policy_json" {
  type        = string
  description = "Resource policy. Required in practice for a PRIVATE API, which otherwise allows nothing."
  default     = null
}

variable "manage_account_cloudwatch_role" {
  type        = bool
  description = "Create the IAM role API Gateway uses to write logs and set it on the account. Access logging fails without that account setting, but it is one per account and region, so leave this off where something else already manages it."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
