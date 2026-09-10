variable "region" {
  type        = string
  description = "Region the bucket and logs live in. CloudFront itself is global."
  default     = "us-east-1"
}

variable "name" {
  type        = string
  description = "Name prefix for the site."
  default     = "site"
}

variable "environment" {
  type        = string
  description = "Environment name, used for tagging."
  default     = "production"
}

variable "domain_name" {
  type        = string
  description = "Domain the site answers on, such as www.example.com."
}

variable "hosted_zone_name" {
  type        = string
  description = "Route 53 zone holding that domain."
}

variable "additional_domains" {
  type        = list(string)
  description = "Extra names the distribution answers on. Each gets a record and goes on the certificate."
  default     = []
}

variable "single_page_app" {
  type        = bool
  description = "Serve index.html with a 200 for 403 and 404, so client-side routing works on a deep link."
  default     = true
}

variable "price_class" {
  type        = string
  description = "Which edge locations serve traffic. PriceClass_100 is North America and Europe only."
  default     = "PriceClass_100"
}

variable "geo_restriction" {
  type = object({
    type      = string
    locations = list(string)
  })
  description = "Geographic restriction, whitelist or blacklist with two-letter country codes. Null allows everywhere."
  default     = null
}

variable "enable_waf" {
  type        = bool
  description = "Put a WAF in front. It must be created in us-east-1 for CloudFront, which this example does."
  default     = true
}
