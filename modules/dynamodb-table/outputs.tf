output "name" {
  description = "Name of the table."
  value       = aws_dynamodb_table.this.name
}

output "arn" {
  description = "ARN of the table."
  value       = aws_dynamodb_table.this.arn
}

output "id" {
  description = "ID of the table, which is the same as its name."
  value       = aws_dynamodb_table.this.id
}

output "stream_arn" {
  description = "ARN of the change stream, or null when no stream is enabled."
  value       = aws_dynamodb_table.this.stream_arn
}

output "stream_label" {
  description = "Timestamp identifying the current stream, or null when no stream is enabled."
  value       = aws_dynamodb_table.this.stream_label
}
