locals {
  has_selection = length(var.selection_tags) > 0 || length(var.selection_resource_arns) > 0
  tags          = merge(var.tags, { Name = var.name })
}

data "aws_partition" "current" {}

resource "aws_backup_vault" "this" {
  name        = var.name
  kms_key_arn = var.vault_kms_key_arn

  tags = local.tags
}

resource "aws_backup_vault_lock_configuration" "this" {
  count = var.vault_lock == null ? 0 : 1

  backup_vault_name   = aws_backup_vault.this.name
  changeable_for_days = var.vault_lock.changeable_for_days
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
}

resource "aws_backup_vault_notifications" "this" {
  count = var.notifications == null ? 0 : 1

  backup_vault_name   = aws_backup_vault.this.name
  sns_topic_arn       = var.notifications.sns_topic_arn
  backup_vault_events = var.notifications.events
}

resource "aws_backup_plan" "this" {
  name = var.name

  dynamic "rule" {
    for_each = var.rules

    content {
      rule_name         = rule.key
      target_vault_name = aws_backup_vault.this.name
      schedule          = rule.value.schedule

      start_window      = rule.value.start_window_minutes
      completion_window = rule.value.completion_window_minutes

      enable_continuous_backup = rule.value.enable_continuous_backup
      recovery_point_tags      = merge(var.tags, rule.value.recovery_point_tags)

      lifecycle {
        delete_after       = rule.value.delete_after_days
        cold_storage_after = rule.value.cold_storage_after_days
      }

      dynamic "copy_action" {
        for_each = rule.value.copy_to_vault_arn == null ? [] : [rule.value]

        content {
          destination_vault_arn = copy_action.value.copy_to_vault_arn

          lifecycle {
            delete_after = copy_action.value.copy_delete_after_days
          }
        }
      }
    }
  }

  tags = local.tags
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = format("%s-backup-", substr(var.name, 0, 16))
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.this.name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup", data.aws_partition.current.partition)
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.this.name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores", data.aws_partition.current.partition)
}

resource "aws_backup_selection" "this" {
  count = local.has_selection ? 1 : 0

  name         = format("%s-selection", var.name)
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.this.arn

  resources     = length(var.selection_resource_arns) > 0 ? var.selection_resource_arns : ["*"]
  not_resources = var.not_resources

  dynamic "selection_tag" {
    for_each = var.selection_tags

    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }
}
