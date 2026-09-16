output "arn" {
  description = "ARN of the delivery stream. This is the firehose_arn a metric stream or a log subscription writes to."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "name" {
  description = "Name of the delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "destination" {
  description = "Destination type the stream was built for, either extended_s3 or http_endpoint."
  value       = aws_kinesis_firehose_delivery_stream.this.destination
}
