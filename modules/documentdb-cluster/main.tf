locals {
  tags = merge(var.tags, { Name = var.name })

  # Audit logging stays on unless the caller sets audit_logs themselves.
  parameters = merge({ audit_logs = "enabled" }, var.parameters)
}

resource "aws_docdb_subnet_group" "this" {
  name        = format("%s-subnets", var.name)
  subnet_ids  = var.subnet_ids
  description = format("Subnets for %s", var.name)

  tags = local.tags
}

resource "aws_docdb_cluster_parameter_group" "this" {
  name_prefix = format("%s-", var.name)
  family      = var.parameter_group_family
  description = format("Parameters for %s", var.name)

  dynamic "parameter" {
    for_each = local.parameters

    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

moved {
  from = aws_docdb_cluster_parameter_group.this[0]
  to   = aws_docdb_cluster_parameter_group.this
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier = var.name
  engine             = "docdb"
  engine_version     = var.engine_version
  port               = var.port

  master_username             = var.username
  manage_master_user_password = var.manage_master_password ? true : null
  master_password             = var.manage_master_password ? null : var.password

  db_subnet_group_name            = aws_docdb_subnet_group.this.name
  vpc_security_group_ids          = var.security_group_ids
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : format("%s-final-%s", var.name, formatdate("YYYYMMDDhhmmss", timestamp()))

  tags = local.tags

  lifecycle {
    ignore_changes = [final_snapshot_identifier]

    precondition {
      condition     = var.manage_master_password || var.password != null
      error_message = "Set manage_master_password, or supply a password."
    }
  }
}

resource "aws_docdb_cluster_instance" "this" {
  count = var.instance_count

  identifier         = format("%s-%02d", var.name, count.index + 1)
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class

  tags = merge(var.tags, { Name = format("%s-%02d", var.name, count.index + 1) })
}
