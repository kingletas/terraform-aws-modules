output "arns" {
  description = "Parameter ARNs, keyed by the name the caller gave."
  value       = { for name, parameter in aws_ssm_parameter.this : name => parameter.arn }
}

output "names" {
  description = "Full parameter paths, keyed by the name the caller gave. This is what an application reads a parameter by."
  value       = { for name, parameter in aws_ssm_parameter.this : name => parameter.name }
}

output "versions" {
  description = "Current version number of each parameter, keyed by the name the caller gave."
  value       = { for name, parameter in aws_ssm_parameter.this : name => parameter.version }
}
