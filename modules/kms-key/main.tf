locals {
  symmetric = var.customer_master_key_spec == "SYMMETRIC_DEFAULT"
  tags      = merge(var.tags, { Name = var.name })
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Without an explicit policy a key falls back to one granting account root everything.
data "aws_iam_policy_document" "this" {
  statement {
    sid       = "AllowAccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = length(var.admin_arns) > 0 ? var.admin_arns : [
        format("arn:%s:iam::%s:root", data.aws_partition.current.partition, data.aws_caller_identity.current.account_id)
      ]
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
