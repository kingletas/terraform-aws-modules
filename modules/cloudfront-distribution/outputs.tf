output "id" {
  description = "ID of the distribution, which an invalidation command needs."
  value       = aws_cloudfront_distribution.this.id
}

output "arn" {
  description = "ARN of the distribution. An S3 bucket policy uses this to allow only this distribution."
  value       = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  description = "CloudFront domain name. Point an alias record at this."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "hosted_zone_id" {
  description = "Hosted zone ID for a Route 53 alias record. The same for every CloudFront distribution."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "status" {
  description = "Deployment status. A change takes several minutes to reach every edge location."
  value       = aws_cloudfront_distribution.this.status
}

output "origin_access_control_ids" {
  description = "Origin access control IDs created here, keyed by origin ID."
  value       = { for id, control in aws_cloudfront_origin_access_control.this : id => control.id }
}
