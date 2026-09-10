variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Project name. Every resource is named from it."
  default     = "storefront"
}

variable "environment" {
  type        = string
  description = "Which environment this is. It decides sizing, retention, capacity and whether production guards apply."
  default     = "staging"

  validation {
    condition     = contains(["dev", "staging", "uat", "production"], var.environment)
    error_message = "The environment must be dev, staging, uat or production."
  }
}

variable "owner" {
  type        = string
  description = "Team answerable for this stack."
  default     = "webops"
}

variable "domain_name" {
  type        = string
  description = "Storefront domain, such as shop.example.com."
}

variable "hosted_zone_name" {
  type        = string
  description = "Route 53 zone holding that domain."
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR for the VPC."
  default     = "10.80.0.0/16"
}

variable "ami_id" {
  type        = string
  description = <<-EOT
    Base AMI for every node, with your PHP version, extensions, the SSM agent
    and the CloudWatch agent baked in.

    The AMI is the unit of deployment for the web tier: a release is a new AMI
    and an instance refresh, not a file copied onto a running node.
  EOT
}

variable "instance_types" {
  type        = map(string)
  description = "Web node instance type per environment. Magento is PHP-bound, so cores matter more than memory."

  default = {
    dev        = "t3.large"
    staging    = "c7g.large"
    uat        = "c7g.large"
    production = "c7g.xlarge"
  }
}

variable "web_capacity" {
  type = object({
    min     = optional(number)
    desired = optional(number)
    max     = optional(number)
  })
  description = "Web tier capacity. Any field left null takes the environment's own default."
  default     = {}
}

variable "include_builder" {
  type        = bool
  description = "Run a builder node that compiles releases. Turn it off where CI builds the AMI, which is the better arrangement."
  default     = false
}

variable "enable_waf" {
  type        = bool
  description = "Put a WAF in front of CloudFront. It is the largest fixed cost on a low-traffic environment."
  default     = true
}

variable "alert_email" {
  type        = string
  description = "Address receiving alarm notifications. It must be confirmed by hand."
  default     = null
}
