variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for everything this example creates."
  default     = "vpn-demo"
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for the VPC."
  default     = "10.20.0.0/16"
}

variable "client_cidr_block" {
  type        = string
  description = "Address pool handed to connecting clients. Must not overlap vpc_cidr."
  default     = "10.100.0.0/22"
}

variable "server_certificate_body" {
  type        = string
  description = "PEM body of the server certificate."
  sensitive   = true
}

variable "server_private_key" {
  type        = string
  description = "PEM private key for the server certificate."
  sensitive   = true
}

variable "client_root_certificate_body" {
  type        = string
  description = "PEM body of the client certificate authority."
  sensitive   = true
}

variable "client_root_private_key" {
  type        = string
  description = "PEM private key for the client certificate authority."
  sensitive   = true
}

variable "certificate_chain" {
  type        = string
  description = "PEM certificate authority chain shared by both certificates."
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "sandbox"
}
