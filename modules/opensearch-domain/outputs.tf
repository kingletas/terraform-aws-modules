output "id" {
  description = "ID of the domain."
  value       = aws_opensearch_domain.this.id
}

output "arn" {
  description = "ARN of the domain."
  value       = aws_opensearch_domain.this.arn
}

output "endpoint" {
  description = "Endpoint to send search and index requests to."
  value       = aws_opensearch_domain.this.endpoint
}

output "dashboard_endpoint" {
  description = "Endpoint of the OpenSearch Dashboards interface."
  value       = aws_opensearch_domain.this.dashboard_endpoint
}

output "domain_name" {
  description = "Name of the domain."
  value       = aws_opensearch_domain.this.domain_name
}
