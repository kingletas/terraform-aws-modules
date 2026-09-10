output "arns" {
  description = "Alarm ARNs, keyed by alarm name."
  value       = { for name, alarm in aws_cloudwatch_metric_alarm.this : name => alarm.arn }
}

output "names" {
  description = "Alarm names, which is also the map's keys."
  value       = keys(aws_cloudwatch_metric_alarm.this)
}
