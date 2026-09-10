variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for everything this example creates."
  default     = "app-demo"
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for the VPC."
  default     = "10.30.0.0/16"
}

variable "instance_count" {
  type        = number
  description = "How many application instances to launch."
  default     = 2
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.small"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "sandbox"
}
