data "aws_partition" "current" {}

locals {
  create_parameter_group = length(var.parameters) > 0
  monitoring_enabled     = var.monitoring_interval > 0

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_db_subnet_group" "this" {
  name        = format("%s-subnets", var.name)
  subnet_ids  = var.subnet_ids
  description = format("Subnets for %s", var.name)

  tags = local.tags
}

resource "aws_db_parameter_group" "this" {
  count = local.create_parameter_group ? 1 : 0

  name_prefix = format("%s-", var.name)
  family      = var.parameter_group_family
  description = format("Parameters for %s", var.name)

  dynamic "parameter" {
    for_each = var.parameters

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

data "aws_iam_policy_document" "monitoring_assume_role" {
  count = local.monitoring_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  count = local.monitoring_enabled ? 1 : 0

  name_prefix        = format("%s-rds-mon-", substr(var.name, 0, 16))
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume_role[0].json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = local.monitoring_enabled ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole", data.aws_partition.current.partition)
}

resource "aws_db_instance" "this" {
  identifier = var.name

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name                     = var.database_name
  username                    = var.username
  manage_master_user_password = var.manage_master_password ? true : null
  password                    = var.manage_master_password ? null : var.password
  port                        = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  parameter_group_name   = local.create_parameter_group ? aws_db_parameter_group.this[0].name : null
  publicly_accessible    = false

  multi_az                   = var.multi_az
  backup_retention_period    = var.backup_retention_period
  backup_window              = var.backup_window
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = local.monitoring_enabled ? aws_iam_role.monitoring[0].arn : null
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  # Set even when skipped, so turning skip_final_snapshot off later still leaves a name for the destroy to use.
  final_snapshot_identifier = format("%s-final", var.name)
  copy_tags_to_snapshot     = true
  delete_automated_backups  = var.delete_automated_backups

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.manage_master_password || var.password != null
      error_message = "Set manage_master_password, or supply a password."
    }

    precondition {
      condition     = !local.create_parameter_group || var.parameter_group_family != null
      error_message = "Supplying parameters needs parameter_group_family, such as postgres16."
    }
  }
}
