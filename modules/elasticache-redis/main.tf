locals {
  create_parameter_group = length(var.parameters) > 0
  failover_possible      = var.replicas_per_node_group > 0
  cluster_mode           = var.num_node_groups > 1

  # Sharding needs cluster-enabled, which the plain default parameter group turns off.
  parameters = local.cluster_mode ? merge(var.parameters, { cluster-enabled = "yes" }) : var.parameters

  parameter_group_name = (
    local.create_parameter_group ? aws_elasticache_parameter_group.this[0].name :
    local.cluster_mode ? format("default.%s.cluster.on", coalesce(var.parameter_group_family, "unset")) :
    null
  )

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_elasticache_subnet_group" "this" {
  name        = format("%s-subnets", var.name)
  subnet_ids  = var.subnet_ids
  description = format("Subnets for %s", var.name)

  tags = local.tags
}

resource "aws_elasticache_parameter_group" "this" {
  count = local.create_parameter_group ? 1 : 0

  # The family is in the name, because a family change replaces the group and create_before_destroy needs the new name to be free.
  name        = format("%s-params-%s", var.name, replace(coalesce(var.parameter_group_family, "unset"), ".", "-"))
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

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = format("%s cache", var.name)

  engine         = var.engine
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = var.security_group_ids
  parameter_group_name = local.parameter_group_name

  automatic_failover_enabled = local.failover_possible && var.automatic_failover_enabled
  multi_az_enabled           = local.failover_possible && var.automatic_failover_enabled && var.multi_az_enabled

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token
  kms_key_id                 = var.at_rest_encryption_enabled ? var.kms_key_arn : null

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_retention_limit > 0 ? var.snapshot_window : null
  maintenance_window       = var.maintenance_window

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery

    content {
      log_type         = log_delivery_configuration.key
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.auth_token == null || var.transit_encryption_enabled
      error_message = "An auth token needs transit encryption turned on."
    }

    precondition {
      condition     = !local.create_parameter_group || var.parameter_group_family != null
      error_message = "Supplying parameters needs parameter_group_family, such as valkey8."
    }

    precondition {
      condition     = !local.cluster_mode || var.parameter_group_family != null
      error_message = "More than one node group needs parameter_group_family, such as valkey8, so the module can choose a parameter group with cluster-enabled on."
    }
  }
}
