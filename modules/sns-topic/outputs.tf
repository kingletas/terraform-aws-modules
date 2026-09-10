output "arn" {
  description = "ARN of the topic, which is what a publisher and an alarm action need."
  value       = aws_sns_topic.this.arn
}

output "id" {
  description = "ID of the topic, which is the same as its ARN."
  value       = aws_sns_topic.this.id
}

output "name" {
  description = "Name of the topic, including the .fifo suffix where one applies."
  value       = aws_sns_topic.this.name
}

output "subscription_arns" {
  description = "Subscription ARNs, keyed by the name you gave each one."
  value       = { for name, subscription in aws_sns_topic_subscription.this : name => subscription.arn }
}
