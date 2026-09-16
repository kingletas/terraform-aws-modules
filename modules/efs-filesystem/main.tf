resource "aws_efs_file_system" "this" {
  creation_token = var.name
  encrypted      = true
  kms_key_id     = var.kms_key_arn

  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_ia_days == null ? [] : [var.transition_to_ia_days]

    content {
      transition_to_ia = lifecycle_policy.value
    }
  }

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.enable_backup ? "ENABLED" : "DISABLED"
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = var.subnet_ids

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = var.security_group_ids
}

# A file system policy replaces the default one, so it must allow mounting as well as requiring TLS.
data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AllowMountThroughMountTargets"
    effect = "Allow"

    actions   = var.allow_client_root_access ? ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"] : ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
    resources = [aws_efs_file_system.this.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }
  }

  statement {
    sid    = "EnforceTlsInTransit"
    effect = "Deny"

    actions   = ["*"]
    resources = [aws_efs_file_system.this.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy         = data.aws_iam_policy_document.this.json
}

resource "aws_efs_access_point" "this" {
  for_each = var.access_points

  file_system_id = aws_efs_file_system.this.id

  root_directory {
    path = each.value.path

    creation_info {
      owner_uid   = each.value.owner_uid
      owner_gid   = each.value.owner_gid
      permissions = each.value.permissions
    }
  }

  posix_user {
    uid            = each.value.posix_uid
    gid            = each.value.posix_gid
    secondary_gids = each.value.secondary_gids
  }

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}
