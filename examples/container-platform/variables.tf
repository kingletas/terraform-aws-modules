variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the platform."
  default     = "platform"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging and naming."
  default     = "production"
}

variable "domain_name" {
  type        = string
  description = "Domain the service answers on."
}

variable "hosted_zone_name" {
  type        = string
  description = "Route 53 zone holding that domain."
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR for the VPC."
  default     = "10.50.0.0/16"
}

variable "services" {
  type = map(object({
    image_tag      = string
    container_port = optional(number, 8080)
    path_patterns  = optional(list(string))
    priority       = optional(number)

    cpu    = optional(number, 512)
    memory = optional(number, 1024)

    min_capacity = optional(number, 2)
    max_capacity = optional(number, 20)
    cpu_target   = optional(number, 60)

    environment = optional(map(string), {})
    health_path = optional(string, "/healthz")
  }))
  description = "Services to run, keyed by name. Each gets a repository, a task definition, a service and a target group."

  default = {
    api = {
      image_tag     = "v1.0.0"
      path_patterns = ["/api/*"]
      priority      = 100
    }
    web = {
      image_tag = "v1.0.0"
    }
  }
}

variable "default_service" {
  type        = string
  description = "Service receiving traffic that matches no path rule."
  default     = "web"
}

variable "database_max_capacity" {
  type        = number
  description = "Aurora Serverless v2 ceiling in ACUs."
  default     = 8
}

variable "untagged_image_expiry_days" {
  type        = number
  description = "Days before an untagged image is expired. Every build that is replaced leaves one behind."
  default     = 7
}

variable "max_tagged_images" {
  type        = number
  description = "Tagged images kept per repository. Keep enough to roll back through, not every build ever made."
  default     = 30
}

variable "alert_email" {
  type        = string
  description = "Address receiving alarm notifications. It must be confirmed by hand."
  default     = null
}
