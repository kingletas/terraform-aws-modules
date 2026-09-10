variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the warehouse."
  default     = "warehouse"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging and naming."
  default     = "production"
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR for the warehouse VPC."
  default     = "10.70.0.0/16"
}

variable "sources" {
  type = map(object({
    engine        = string
    database_name = optional(string)
    description   = optional(string)

    table_mappings_json = optional(string)
    migration_type      = optional(string, "full-load-and-cdc")
  }))
  description = <<-EOT
    Source systems to replicate into the warehouse, keyed by name. The engine is
    a DMS engine name such as sqlserver, oracle, mysql or postgres.

    Credentials are not here. Each source gets an empty secret you populate out
    of band, so nothing readable passes through Terraform state.
  EOT

  default = {
    erp = {
      engine        = "sqlserver"
      database_name = "erp"
      description   = "Enterprise resource planning system"
    }
  }
}

variable "redshift_node_type" {
  type        = string
  description = "Redshift node type. The ra3 family separates compute from storage."
  default     = "ra3.large"
}

variable "redshift_nodes" {
  type        = number
  description = "Redshift nodes."
  default     = 2
}

variable "dms_instance_class" {
  type        = string
  description = "DMS replication instance class. Sized by change volume, not by source size."
  default     = "dms.t3.medium"
}

variable "airflow_version" {
  type        = string
  description = "Airflow version for the MWAA environment."
  default     = "2.10.3"
}

variable "airflow_environment_class" {
  type        = string
  description = "MWAA environment class."
  default     = "mw1.small"
}

variable "airflow_max_workers" {
  type        = number
  description = "Ceiling for MWAA worker autoscaling."
  default     = 5
}

variable "alert_email" {
  type        = string
  description = "Address receiving alarm notifications. It must be confirmed by hand."
  default     = null
}
