locals {
  symmetric  = var.customer_master_key_spec == "SYMMETRIC_DEFAULT"
  add_caller = var.include_caller_as_admin && length(var.admin_arns) > 0
  tags       = merge(var.tags, { Name = var.name })
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Resolves an assumed-role session to its role, which is what a key policy can name stably.
data "aws_iam_session_context" "caller" {
  count = local.add_caller ? 1 : 0

  arn = data.aws_caller_identity.current.arn
}

# Without an explicit policy a key falls back to one granting account root everything.
data "aws_iam_policy_document" "this" {
  statement {
    sid       = "AllowAccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = length(var.admin_arns) == 0 ? [
        format("arn:%s:iam::%s:root", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id)
      ] : distinct(concat(var.admin_arns, local.add_caller ? [data.aws_iam_session_context.caller[0].issuer_arn] : []))
    }
  }

  dynamic "statement" {
    for_each = length(var.user_arns) > 0 ? [1] : []

    content {
      sid    = "AllowUse"
      effect = "Allow"

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]

      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.user_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []

    content {
      sid    = "AllowServiceUse"
      effect = "Allow"

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]

      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.service_principals
      }

      # IfExists keeps use working for a service that does not send its source account.
      condition {
        test     = "StringEqualsIfExists"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.delivery_service_principals) > 0 ? [1] : []

    content {
      sid       = "AllowDeliveryServices"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.delivery_service_principals
      }

      # IfExists keeps delivery working for a service that does not send its source account.
      condition {
        test     = "StringEqualsIfExists"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description              = var.description
  key_usage                = var.key_usage
  customer_master_key_spec = var.customer_master_key_spec
  multi_region             = var.multi_region

  enable_key_rotation     = local.symmetric && var.enable_key_rotation
  rotation_period_in_days = local.symmetric && var.enable_key_rotation ? var.rotation_period_in_days : null

  deletion_window_in_days = var.deletion_window_in_days
  policy                  = coalesce(var.policy_json, data.aws_iam_policy_document.this.json)

  tags = local.tags
}

resource "aws_kms_alias" "this" {
  name          = format("alias/%s", var.name)
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_kms_alias" "extra" {
  for_each = toset(var.aliases)

  name          = format("alias/%s", each.value)
  target_key_id = aws_kms_key.this.key_id
}
