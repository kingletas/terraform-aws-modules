output "id" {
  description = "Name of the bucket."
  value       = aws_s3_bucket.this.id
}

output "arn" {
  description = "ARN of the bucket."
  value       = aws_s3_bucket.this.arn
}

output "domain_name" {
  description = "Global domain name of the bucket."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "regional_domain_name" {
  description = "Regional domain name, which is what CloudFront and cross-region callers should use."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID for the bucket's region, for an alias record."
  value       = aws_s3_bucket.this.hosted_zone_id
}
