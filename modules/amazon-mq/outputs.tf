output "id" {
  description = "Identifier of the broker."
  value       = aws_mq_broker.this.id
}

output "arn" {
  description = "ARN of the broker."
  value       = aws_mq_broker.this.arn
}

output "instances" {
  description = "Every broker instance, each with its console URL, endpoints and IP address."
  value       = aws_mq_broker.this.instances
}

output "endpoints" {
  description = "Wire protocol endpoints across every instance. RabbitMQ publishes one amqps endpoint; ActiveMQ publishes five, one per protocol."
  value       = flatten(aws_mq_broker.this.instances[*].endpoints)
}

output "primary_endpoint" {
  description = "First endpoint on the first instance, which is what a single-endpoint client configuration takes."
  value       = try(aws_mq_broker.this.instances[0].endpoints[0], null)
}

output "console_url" {
  description = "Management console of the first instance."
  value       = try(aws_mq_broker.this.instances[0].console_url, null)
}

output "configuration_id" {
  description = "Identifier of the configuration this module created, or null when the engine defaults are in use."
  value       = var.configuration == null ? null : aws_mq_configuration.this[0].id
}
