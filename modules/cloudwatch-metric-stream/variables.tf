variable "name" {
  type        = string
  description = "Metric stream name, unique within the account and region."
}

variable "role_arn" {
  type        = string
  description = "Role CloudWatch assumes to write to the delivery stream. It needs firehose:PutRecord and firehose:PutRecordBatch on that stream."
}

variable "firehose_arn" {
  type        = string
  description = "Delivery stream metrics are written to. Build it with the kinesis-firehose module."
}

variable "output_format" {
  type        = string
  description = "Wire format. json is what most vendors accept; the OpenTelemetry formats are smaller and carry resource attributes."
  default     = "json"

  validation {
    condition     = contains(["json", "opentelemetry0.7", "opentelemetry1.0"], var.output_format)
    error_message = "The output_format must be json, opentelemetry0.7 or opentelemetry1.0."
  }
}

variable "include_namespaces" {
  type        = map(list(string))
  description = "Namespaces to stream, keyed by namespace, each an explicit list of metric names or an empty list for every metric in it. Set this or exclude_namespaces, not both."
  default     = {}
}

variable "exclude_namespaces" {
  type        = map(list(string))
  description = "Namespaces to leave out, keyed the same way. Everything else streams. Set this or include_namespaces, not both."
  default     = {}
}

variable "statistics_configurations" {
  type = map(object({
    additional_statistics = list(string)
    metrics = list(object({
      namespace   = string
      metric_name = string
    }))
  }))
  description = "Extra statistics beyond the default four, keyed by a name you choose. Percentiles are charged per statistic, so name the metrics that need them rather than a whole namespace."
  default     = {}

  validation {
    condition = alltrue([
      for _, configuration in var.statistics_configurations :
      length(configuration.additional_statistics) > 0 && length(configuration.metrics) > 0
    ])
    error_message = "A statistics configuration needs at least one statistic and at least one metric."
  }
}

variable "include_linked_accounts_metrics" {
  type        = bool
  description = "Also stream metrics shared into this account by a monitoring account link."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
