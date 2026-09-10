output "name" {
  description = "Name of the repository."
  value       = aws_ecr_repository.this.name
}

output "arn" {
  description = "ARN of the repository."
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "URL to push and pull from, which is what a docker tag needs."
  value       = aws_ecr_repository.this.repository_url
}

output "registry_id" {
  description = "Account ID of the registry holding this repository."
  value       = aws_ecr_repository.this.registry_id
}
