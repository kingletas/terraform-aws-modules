locals {
  create_parameter_group = length(var.cluster_parameters) > 0
  uses_serverless        = anytrue([for instance in var.instances : instance.instance_class == "db.serverless"])
  monitoring_enabled     = var.monitoring_interval > 0

  tags = merge(var.tags, { Name = var.name })
}

data "aws_partition" "current" {}

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

resource "aws_db_subnet_group" "this" {
  name        = format("%s-subnets", var.name)
  subnet_ids  = var.subnet_ids
  description = format("Subnets for %s", var.name)

  tags = local.tags
}

resource "aws_rds_cluster_parameter_group" "this" {
  count = local.create_parameter_group ? 1 : 0

  name_prefix = format("%s-", var.name)
  family      = var.parameter_group_family
  description = format("Cluster parameters for %s", var.name)

  dynamic "parameter" {
    for_each = var.cluster_parameters

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

resource "aws_rds_cluster" "this" {
  cluster_identifier = var.name

  engine         = var.engine
  engine_version = var.engine_version
  engine_mode    = var.engine_mode

  database_name               = var.database_name
  master_username             = var.username
  manage_master_user_password = var.manage_master_password ? true : null
  master_password             = var.manage_master_password ? null : var.password
  port                        = var.port

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = var.security_group_ids
  db_cluster_parameter_group_name = local.create_parameter_group ? aws_rds_cluster_parameter_group.this[0].name : null

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  copy_tags_to_snapshot        = true

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  # Set even when skipped, so turning skip_final_snapshot off later still leaves a name for the destroy to use.
  final_snapshot_identifier = format("%s-final", var.name)
  apply_immediately         = var.apply_immediately

  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.uses_serverless ? [var.serverless_capacity] : []

    content {
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.manage_master_password || var.password != null
      error_message = "Set manage_master_password, or supply a password."
    }

    precondition {
      condition     = !local.create_parameter_group || var.parameter_group_family != null
      error_message = "Supplying cluster_parameters needs parameter_group_family."
    }
  }
}

resource "aws_rds_cluster_instance" "this" {
  for_each = var.instances

  identifier         = format("%s-%s", var.name, each.key)
  cluster_identifier = aws_rds_cluster.this.id

  engine         = aws_rds_cluster.this.engine
  engine_version = aws_rds_cluster.this.engine_version
  instance_class = each.value.instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name
  availability_zone    = each.value.availability_zone
  publicly_accessible  = each.value.publicly_accessible
  promotion_tier       = each.value.promotion_tier

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? var.kms_key_arn : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = local.monitoring_enabled ? aws_iam_role.monitoring[0].arn : null

  apply_immediately = var.apply_immediately

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}
