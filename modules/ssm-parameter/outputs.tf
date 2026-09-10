output "arns" {
  description = "Parameter ARNs, keyed by path."
  value       = { for path, parameter in aws_ssm_parameter.this : path => parameter.arn }
}

output "names" {
  description = "Parameter names, keyed by path."
  value       = { for path, parameter in aws_ssm_parameter.this : path => parameter.name }
}

output "versions" {
  description = "Current version number of each parameter, keyed by path."
  value       = { for path, parameter in aws_ssm_parameter.this : path => parameter.version }
}
