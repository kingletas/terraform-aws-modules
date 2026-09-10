locals {
  generate = var.public_key == null

  public_key = local.generate ? tls_private_key.this[0].public_key_openssh : var.public_key
  store      = local.generate && var.store_in_secrets_manager
}

# A generated private key is in Terraform state, in clear text. That is
# unavoidable, and it is why supplying an existing public key is the better path
# for anything long-lived.
resource "tls_private_key" "this" {
  count = local.generate ? 1 : 0

  algorithm = var.algorithm
  rsa_bits  = var.algorithm == "RSA" ? var.rsa_bits : null
}

resource "aws_key_pair" "this" {
  key_name   = var.name
  public_key = local.public_key

  tags = merge(var.tags, { Name = var.name })
}

resource "local_sensitive_file" "private_key" {
  count = local.generate && var.write_private_key_to != null ? 1 : 0

  filename        = pathexpand(var.write_private_key_to)
  content         = tls_private_key.this[0].private_key_openssh
  file_permission = "0600"
}

resource "aws_secretsmanager_secret" "this" {
  # checkov:skip=CKV2_AWS_57: rotating this means a new key pair re-registered on every instance, which no rotation function can do
  count = local.store ? 1 : 0

  name        = format("ssh/%s", var.name)
  description = format("Private key for the %s EC2 key pair", var.name)
  kms_key_id  = var.kms_key_arn

  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_secretsmanager_secret_version" "this" {
  count = local.store ? 1 : 0

  secret_id = aws_secretsmanager_secret.this[0].id

  secret_string = jsonencode({
    private_key = tls_private_key.this[0].private_key_openssh
    public_key  = tls_private_key.this[0].public_key_openssh
    fingerprint = aws_key_pair.this.fingerprint
  })
}
