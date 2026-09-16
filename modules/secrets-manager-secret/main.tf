locals {
  # Whether a value was supplied is not itself a secret, only the value is.
  has_initial_version = nonsensitive(var.initial_version != null) || var.generate_password

  secret_string = (
    var.generate_password ? random_password.this[0].result
    : var.initial_version == null ? null
    : var.initial_version.json != null ? jsonencode(var.initial_version.json)
    : var.initial_version.value
  )
}

resource "random_password" "this" {
  count = var.generate_password ? 1 : 0

  length           = var.password_length
  special          = true
  override_special = var.password_override_special
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
}

resource "aws_secretsmanager_secret" "this" {
  name        = var.name
  description = var.description
  kms_key_id  = var.kms_key_arn

  recovery_window_in_days = var.recovery_window_in_days

  dynamic "replica" {
    for_each = var.replica_regions

    content {
      region     = replica.key
      kms_key_id = replica.value.kms_key_id
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = !(var.generate_password && nonsensitive(var.initial_version != null))
      error_message = "Set initial_version or generate_password, not both."
    }
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  count = local.has_initial_version ? 1 : 0

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = local.secret_string

  lifecycle {
    # Rotation and out-of-band updates own the value after the first write.
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  count = var.attach_policy ? 1 : 0

  secret_arn = aws_secretsmanager_secret.this.arn
  policy     = var.policy_json
}

resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.rotation == null ? 0 : 1

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation.lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation.automatically_after_days
    duration                 = var.rotation.duration
  }
}
