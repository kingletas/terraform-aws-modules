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
  # checkov:skip=CKV_AWS_105: require_ssl is a static parameter below, from var.require_ssl which defaults to true; the check cannot resolve the variable
  name        = format("%s-params", var.name)
  family      = var.parameter_group_family
  description = format("Parameters for %s", var.name)

  # The group is always created so require_ssl is never left to the default group, where it is off.
  parameter {
    name  = "require_ssl"
    value = tostring(var.require_ssl)
  }

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = local.tags
}

moved {
  from = aws_redshift_parameter_group.this[0]
  to   = aws_redshift_parameter_group.this
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
  cluster_parameter_group_name = aws_redshift_parameter_group.this.name

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

  skip_final_snapshot = var.skip_final_snapshot
  # Set even when skipped, so turning skip_final_snapshot off later still leaves a name for the destroy to use.
  final_snapshot_identifier = format("%s-final", var.name)

  tags = local.tags

  lifecycle {
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

# Provider 6 configures audit logging with this separate resource rather than an
# inline block on the cluster.
resource "aws_redshift_logging" "this" {
  count = var.logging == null ? 0 : 1

  cluster_identifier   = aws_redshift_cluster.this.id
  log_destination_type = "s3"
  bucket_name          = var.logging.bucket
  s3_key_prefix        = coalesce(var.logging.prefix, format("%s/", var.name))
}
