output "id" {
  description = "URL of the queue, which is what a client sends to."
  value       = aws_sqs_queue.this.id
}

output "arn" {
  description = "ARN of the queue, for IAM policies and event source mappings."
  value       = aws_sqs_queue.this.arn
}

output "name" {
  description = "Name of the queue, including the .fifo suffix where one applies."
  value       = aws_sqs_queue.this.name
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue, or null when it is disabled."
  value       = local.dlq_enabled ? aws_sqs_queue.dead_letter[0].arn : null
}

output "dead_letter_queue_url" {
  description = "URL of the dead letter queue, or null when it is disabled."
  value       = local.dlq_enabled ? aws_sqs_queue.dead_letter[0].id : null
}
