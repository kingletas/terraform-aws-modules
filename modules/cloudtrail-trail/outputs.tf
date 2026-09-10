output "arn" {
  description = "ARN of the trail."
  value       = aws_cloudtrail.this.arn
}

output "name" {
  description = "Name of the trail."
  value       = aws_cloudtrail.this.name
}

output "home_region" {
  description = "Region the trail was created in, which is where a multi-region trail is managed from."
  value       = aws_cloudtrail.this.home_region
}
