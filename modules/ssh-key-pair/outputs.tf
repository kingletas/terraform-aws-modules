output "key_name" {
  description = "Name of the EC2 key pair, which a launch template or instance takes."
  value       = aws_key_pair.this.key_name
}

output "key_pair_id" {
  description = "ID of the EC2 key pair."
  value       = aws_key_pair.this.key_pair_id
}

output "fingerprint" {
  description = "Fingerprint of the public key."
  value       = aws_key_pair.this.fingerprint
}

output "public_key_openssh" {
  description = "The public key in OpenSSH format, whether generated or supplied."
  value       = local.public_key
}

output "private_key_openssh" {
  description = "The generated private key, or null when an existing public key was supplied."
  value       = local.generate ? tls_private_key.this[0].private_key_openssh : null
  sensitive   = true
}

output "secret_arn" {
  description = "Secrets Manager secret holding the generated private key, or null when it is not stored."
  value       = local.store ? aws_secretsmanager_secret.this[0].arn : null
}

output "was_generated" {
  description = "Whether the module generated the key rather than registering one you supplied."
  value       = local.generate
}
