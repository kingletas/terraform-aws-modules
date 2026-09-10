variable "name" {
  type        = string
  description = "Environment name."
}

variable "airflow_version" {
  type        = string
  description = "Airflow version. Upgrading is a replacement of the environment, not an in-place change."
  default     = "2.10.3"
}

variable "environment_class" {
  type        = string
  description = "Size of the scheduler and web server: mw1.micro, mw1.small, mw1.medium or mw1.large."
  default     = "mw1.small"

  validation {
    condition     = contains(["mw1.micro", "mw1.small", "mw1.medium", "mw1.large"], var.environment_class)
    error_message = "The environment_class must be mw1.micro, mw1.small, mw1.medium or mw1.large."
  }
}

variable "source_bucket_arn" {
  type        = string
  description = "Bucket holding the DAGs. Versioning must be enabled on it or MWAA refuses to create the environment."
}

variable "dag_s3_path" {
  type        = string
  description = "Prefix inside the bucket holding the DAG files."
  default     = "dags/"
}

variable "requirements_s3_path" {
  type        = string
  description = "Path to requirements.txt. Null installs no extra packages."
  default     = null
}

variable "requirements_s3_object_version" {
  type        = string
  description = "Object version of requirements.txt. MWAA does not notice a changed file at the same key without this."
  default     = null
}

variable "plugins_s3_path" {
  type        = string
  description = "Path to plugins.zip. Null installs no plugins."
  default     = null
}

variable "plugins_s3_object_version" {
  type        = string
  description = "Object version of plugins.zip, for the same reason as requirements."
  default     = null
}

variable "startup_script_s3_path" {
  type        = string
  description = "Path to a startup shell script run on every worker before Airflow starts."
  default     = null
}

variable "execution_role_arn" {
  type        = string
  description = "Role the environment and its tasks run as. It needs the bucket, the logs, SQS and the KMS key."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnets, exactly two, in different availability zones. MWAA accepts no other count."

  validation {
    condition     = length(var.subnet_ids) == 2
    error_message = "MWAA requires exactly two private subnets in different availability zones."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups for the environment. They must allow all traffic from themselves, which is how MWAA's components reach each other."

  validation {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group is required."
  }
}

variable "webserver_access_mode" {
  type        = string
  description = "PRIVATE_ONLY keeps the Airflow UI inside the VPC. PUBLIC_ONLY puts it on the internet behind IAM."
  default     = "PRIVATE_ONLY"

  validation {
    condition     = contains(["PRIVATE_ONLY", "PUBLIC_ONLY"], var.webserver_access_mode)
    error_message = "The webserver_access_mode must be PRIVATE_ONLY or PUBLIC_ONLY."
  }
}

variable "endpoint_management" {
  type        = string
  description = "SERVICE lets MWAA create its own VPC endpoints. CUSTOMER means you create them, which is needed in a shared VPC."
  default     = "SERVICE"
}

variable "max_workers" {
  type        = number
  description = "Ceiling for worker autoscaling."
  default     = 10
}

variable "min_workers" {
  type        = number
  description = "Workers always running. These are billed whether a DAG is scheduled or not."
  default     = 1
}

variable "schedulers" {
  type        = number
  description = "Scheduler count. Two or more needs Airflow 2 and gives scheduler high availability."
  default     = 2
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the environment's data and logs. Null uses the AWS-managed key."
  default     = null
}

variable "airflow_configuration_options" {
  type        = map(string)
  description = "Airflow configuration overrides, using dotted names such as core.default_task_retries."
  default     = {}
}

variable "logging" {
  type = map(object({
    enabled   = optional(bool, true)
    log_level = optional(string, "INFO")
  }))
  description = "Log configuration keyed by dag_processing, scheduler, task, webserver or worker. Task logs are the ones you actually read."

  default = {
    dag_processing = { log_level = "WARNING" }
    scheduler      = { log_level = "WARNING" }
    task           = { log_level = "INFO" }
    webserver      = { log_level = "WARNING" }
    worker         = { log_level = "INFO" }
  }
}

variable "weekly_maintenance_window_start" {
  type        = string
  description = "Weekly maintenance window in UTC, as DAY:HH:MM."
  default     = "SUN:05:00"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the environment."
  default     = {}
}
