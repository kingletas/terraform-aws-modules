locals {
  is_rabbit = var.engine_type == "RabbitMQ"

  valid_deployment_modes = local.is_rabbit ? ["SINGLE_INSTANCE", "CLUSTER_MULTI_AZ"] : ["SINGLE_INSTANCE", "ACTIVE_STANDBY_MULTI_AZ"]

  multi_az = var.deployment_mode != "SINGLE_INSTANCE"

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_mq_configuration" "this" {
  count = var.configuration == null ? 0 : 1

  name           = format("%s-config", var.name)
  description    = try(var.configuration.description, null)
  engine_type    = var.engine_type
  engine_version = var.engine_version
  data           = var.configuration.data

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_mq_broker" "this" {
  broker_name = var.name

  engine_type        = var.engine_type
  engine_version     = var.engine_version
  host_instance_type = var.host_instance_type
  deployment_mode    = var.deployment_mode
  storage_type       = var.storage_type

  subnet_ids          = var.subnet_ids
  security_groups     = var.security_group_ids
  publicly_accessible = var.publicly_accessible

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  encryption_options {
    kms_key_id        = var.kms_key_arn
    use_aws_owned_key = var.kms_key_arn == null
  }

  logs {
    general = var.general_log_enabled
    audit   = local.is_rabbit ? null : var.audit_log_enabled
  }

  dynamic "configuration" {
    for_each = var.configuration == null ? [] : [1]

    content {
      id       = aws_mq_configuration.this[0].id
      revision = aws_mq_configuration.this[0].latest_revision
    }
  }

  dynamic "maintenance_window_start_time" {
    for_each = var.maintenance_window == null ? [] : [var.maintenance_window]

    content {
      day_of_week = maintenance_window_start_time.value.day_of_week
      time_of_day = maintenance_window_start_time.value.time_of_day
      time_zone   = maintenance_window_start_time.value.time_zone
    }
  }

  dynamic "user" {
    for_each = var.users

    content {
      username         = user.key
      password         = user.value.password
      console_access   = local.is_rabbit ? null : user.value.console_access
      groups           = local.is_rabbit ? null : user.value.groups
      replication_user = local.is_rabbit ? null : user.value.replication_user
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = contains(local.valid_deployment_modes, var.deployment_mode)
      error_message = format("%s does not support %s. It supports %s.", var.engine_type, var.deployment_mode, join(" and ", local.valid_deployment_modes))
    }

    precondition {
      condition     = !local.multi_az || length(var.subnet_ids) >= 2
      error_message = "A multi-AZ broker needs at least two subnets, in different availability zones."
    }

    precondition {
      condition     = local.multi_az || length(var.subnet_ids) == 1
      error_message = "A single-instance broker takes exactly one subnet."
    }

    precondition {
      condition     = !local.is_rabbit || length(var.users) == 1
      error_message = "RabbitMQ takes exactly one user here. Further users are created through the RabbitMQ management interface, not through AWS."
    }

    precondition {
      condition     = !local.is_rabbit || !var.audit_log_enabled
      error_message = "RabbitMQ has no audit log. Only the general log can be published."
    }

    precondition {
      condition     = !local.is_rabbit || var.storage_type == null || var.storage_type == "ebs"
      error_message = "RabbitMQ stores on EBS. Only ActiveMQ can use EFS."
    }
  }
}
