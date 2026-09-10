locals {
  single_node = var.number_of_nodes == 1
  tags        = merge(var.tags, { Name = var.name })
}

resource "aws_redshift_subnet_group" "this" {
  name        = format("%s-subnets", var.name)
  subnet_ids  = var.subnet_ids
  description = format("Subnets for %s", var.name)

  tags = local.tags
}

resource "aws_redshift_parameter_group" "this" {
  # checkov:skip=CKV_AWS_105: require_ssl is set, in a dynamic block the check cannot walk
  count = length(var.parameters) > 0 ? 1 : 0

  name        = format("%s-params", var.name)
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
}

resource "aws_redshift_cluster" "this" {
  # checkov:skip=CKV_AWS_71: logging moved to aws_redshift_logging in provider 6; the check still reads the cluster
  cluster_identifier = var.name
  database_name      = var.database_name
  port               = var.port

  node_type = var.node_type

  # A single-node cluster has no cluster_type of multi-node and no node count.
  cluster_type    = local.single_node ? "single-node" : "multi-node"
  number_of_nodes = local.single_node ? null : var.number_of_nodes

  master_username                   = var.username
  manage_master_password            = var.manage_master_password ? true : null
  master_password                   = var.manage_master_password ? null : var.password
  master_password_secret_kms_key_id = var.manage_master_password ? var.kms_key_arn : null

  cluster_subnet_group_name    = aws_redshift_subnet_group.this.id
  vpc_security_group_ids       = var.security_group_ids
  cluster_parameter_group_name = length(var.parameters) > 0 ? aws_redshift_parameter_group.this[0].name : null

  encrypted  = true
  kms_key_id = var.kms_key_arn

  iam_roles            = var.iam_role_arns
  default_iam_role_arn = var.default_iam_role_arn

  # Without this, COPY and UNLOAD traffic leaves over the public network and
  # neither security groups nor VPC endpoints apply to it.
  enhanced_vpc_routing = var.enhanced_vpc_routing
  publicly_accessible  = var.publicly_accessible

  automated_snapshot_retention_period = var.automated_snapshot_retention_period
  manual_snapshot_retention_period    = var.manual_snapshot_retention_period
  preferred_maintenance_window        = var.maintenance_window
  allow_version_upgrade               = var.allow_version_upgrade

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : format("%s-final-%s", var.name, formatdate("YYYYMMDDhhmmss", timestamp()))

  tags = local.tags

  lifecycle {
    ignore_changes = [final_snapshot_identifier]

    precondition {
      condition     = var.manage_master_password || var.password != null
      error_message = "Set manage_master_password, or supply a password."
    }

    precondition {
      condition     = var.default_iam_role_arn == null || contains(var.iam_role_arns, var.default_iam_role_arn)
      error_message = "The default_iam_role_arn must also appear in iam_role_arns."
    }
  }
}

# Provider 6 removed the inline logging block from the cluster in favour of this
# separate resource.
resource "aws_redshift_logging" "this" {
  count = var.logging == null ? 0 : 1

  cluster_identifier   = aws_redshift_cluster.this.id
  log_destination_type = "s3"
  bucket_name          = var.logging.bucket
  s3_key_prefix        = coalesce(var.logging.prefix, format("%s/", var.name))
}
