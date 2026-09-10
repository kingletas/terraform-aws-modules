locals {
  tags = merge(var.tags, { Name = var.name })

  uses_secrets = anytrue([for name, endpoint in var.endpoints : endpoint.secret_arn != null])

  # DMS resolves Secrets Manager over the public address unless told otherwise,
  # and in a private subnet with no route that is a silent hang rather than an
  # error. Appended to whatever the caller already set.
  secrets_override = var.secrets_manager_endpoint_dns == null ? null : format(
    "secretsManagerEndpointOverride=%s", var.secrets_manager_endpoint_dns
  )
}

resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id          = format("%s-subnets", var.name)
  replication_subnet_group_description = format("Subnets for %s", var.name)
  subnet_ids                           = var.subnet_ids

  tags = local.tags
}

resource "aws_dms_replication_instance" "this" {
  replication_instance_id    = var.name
  replication_instance_class = var.instance_class
  engine_version             = var.engine_version
  allocated_storage          = var.allocated_storage

  replication_subnet_group_id = aws_dms_replication_subnet_group.this.id
  vpc_security_group_ids      = var.security_group_ids
  multi_az                    = var.multi_az
  publicly_accessible         = var.publicly_accessible
  auto_minor_version_upgrade  = true
  kms_key_arn                 = var.kms_key_arn

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !local.uses_secrets || var.secrets_access_role_arn != null
      error_message = "An endpoint using a secret needs secrets_access_role_arn, which DMS assumes to read it."
    }
  }
}

resource "aws_dms_endpoint" "this" {
  for_each = var.endpoints

  endpoint_id   = format("%s-%s", var.name, each.key)
  endpoint_type = each.value.endpoint_type
  engine_name   = each.value.engine_name
  kms_key_arn   = var.kms_key_arn
  ssl_mode      = each.value.ssl_mode

  database_name = each.value.database_name

  secrets_manager_arn             = each.value.secret_arn
  secrets_manager_access_role_arn = each.value.secret_arn == null ? null : var.secrets_access_role_arn

  server_name = each.value.secret_arn == null ? each.value.server_name : null
  port        = each.value.secret_arn == null ? each.value.port : null
  username    = each.value.secret_arn == null ? each.value.username : null
  password    = each.value.secret_arn == null ? each.value.password : null

  extra_connection_attributes = trimspace(join(";", compact([
    each.value.extra_connection_attributes,
    each.value.secret_arn == null ? null : local.secrets_override,
  ])))

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}

resource "aws_dms_replication_task" "this" {
  for_each = var.tasks

  replication_task_id      = format("%s-%s", var.name, each.key)
  replication_instance_arn = aws_dms_replication_instance.this.replication_instance_arn

  source_endpoint_arn = aws_dms_endpoint.this[each.value.source_endpoint].endpoint_arn
  target_endpoint_arn = aws_dms_endpoint.this[each.value.target_endpoint].endpoint_arn

  migration_type            = each.value.migration_type
  table_mappings            = each.value.table_mappings_json
  replication_task_settings = each.value.task_settings_json

  start_replication_task = each.value.start_on_create

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })

  lifecycle {
    # A running task's settings drift as DMS records its own progress.
    ignore_changes = [replication_task_settings]

    precondition {
      condition     = contains(keys(var.endpoints), each.value.source_endpoint)
      error_message = format("Task %s names a source_endpoint that is not in endpoints.", each.key)
    }

    precondition {
      condition     = contains(keys(var.endpoints), each.value.target_endpoint)
      error_message = format("Task %s names a target_endpoint that is not in endpoints.", each.key)
    }
  }
}
