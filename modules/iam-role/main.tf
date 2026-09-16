locals {
  has_principals = length(var.trusted_services) > 0 || length(var.trusted_role_arns) > 0 || length(var.trusted_oidc_providers) > 0
  tags           = merge(var.tags, { Name = var.name })

  # IAM statement IDs allow only letters and digits.
  oidc_statement_ids = {
    for key in keys(var.trusted_oidc_providers) :
    key => format("TrustOidc%s", replace(title(replace(key, "/[^A-Za-z0-9]+/", " ")), " ", ""))
  }
}

data "aws_iam_policy_document" "assume_role" {
  dynamic "statement" {
    for_each = length(var.trusted_services) > 0 ? [1] : []

    content {
      sid     = "TrustServices"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "Service"
        identifiers = var.trusted_services
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.trusted_role_arns) > 0 ? [1] : []

    content {
      sid     = "TrustPrincipals"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = var.trusted_role_arns
      }

      dynamic "condition" {
        for_each = var.require_mfa ? [1] : []

        content {
          test     = "Bool"
          variable = "aws:MultiFactorAuthPresent"
          values   = ["true"]
        }
      }

      dynamic "condition" {
        for_each = var.external_id == null ? [] : [var.external_id]

        content {
          test     = "StringEquals"
          variable = "sts:ExternalId"
          values   = [condition.value]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.trusted_oidc_providers

    content {
      sid     = local.oidc_statement_ids[statement.key]
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]

      principals {
        type        = "Federated"
        identifiers = [statement.value.provider_arn]
      }

      condition {
        test     = "StringEquals"
        variable = statement.value.audience_key
        values   = statement.value.audiences
      }

      condition {
        test     = "StringLike"
        variable = statement.value.subject_key
        values   = statement.value.subjects
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix          = format("%s-", var.name)
  description          = var.description
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.has_principals
      error_message = "A role needs at least one trusted service, role ARN or OIDC provider, or nothing can assume it."
    }
  }
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "this" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name_prefix = format("%s-", var.name)
  role        = aws_iam_role.this.name

  tags = local.tags
}
