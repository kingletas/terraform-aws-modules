output "arn" {
  description = "ARN of the metric stream."
  value       = aws_cloudwatch_metric_stream.this.arn
}

output "name" {
  description = "Name of the metric stream."
  value       = aws_cloudwatch_metric_stream.this.name
}

output "state" {
  description = "Whether the stream is running."
  value       = aws_cloudwatch_metric_stream.this.state
}
