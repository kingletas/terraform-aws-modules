data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # MWAA takes exactly two subnets, so the whole stack is built across two zones.
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  prefix             = format("%s-%s", var.name, var.environment)

  tags = {
    Environment = var.environment
    Warehouse   = var.name
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Warehouse, replication and orchestration at rest"

  service_principals = [
    format("logs.%s.amazonaws.com", var.region),
    format("dms.%s.amazonaws.com", var.region),
    "redshift.amazonaws.com",
    "airflow.amazonaws.com",
  ]

  # CloudWatch publishes alarms to the encrypted alert topic.
  delivery_service_principals = ["cloudwatch.amazonaws.com"]

  tags = local.tags
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.prefix
  cidr_block         = var.vpc_cidr
  availability_zones = local.availability_zones

  enable_nat_gateway = true
  single_nat_gateway = false

  flow_log_kms_key_arn = module.kms.arn

  tags = local.tags
}

# --- security groups ---

# MWAA's components reach each other through this group, so it must allow all
# traffic from itself. Without the self rule the environment fails to create,
# roughly twenty minutes in, with a message that does not mention it.
module "airflow_sg" {
  source = "../../modules/security-group"

  name        = format("%s-airflow", local.prefix)
  description = "MWAA scheduler, workers and web server"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    peers = {
      description = "MWAA components reaching each other"
      ip_protocol = "-1"
      self        = true
    }
  }

  tags = local.tags
}

module "dms_sg" {
  source = "../../modules/security-group"

  name        = format("%s-dms", local.prefix)
  description = "DMS replication instance"
  vpc_id      = module.vpc.vpc_id

  # Outbound only. DMS connects out to both source and target; nothing
  # connects in to it.
  ingress_rules = {}

  tags = local.tags
}

module "warehouse_sg" {
  source = "../../modules/security-group"

  name        = format("%s-redshift", local.prefix)
  description = "Redshift cluster"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_dms = {
      description                  = "Redshift port from the replication instance"
      ip_protocol                  = "tcp"
      from_port                    = 5439
      to_port                      = 5439
      referenced_security_group_id = module.dms_sg.id
    }

    from_airflow = {
      description                  = "Redshift port from Airflow workers"
      ip_protocol                  = "tcp"
      from_port                    = 5439
      to_port                      = 5439
      referenced_security_group_id = module.airflow_sg.id
    }
  }

  tags = local.tags
}

module "endpoint_sg" {
  source = "../../modules/security-group"

  name        = format("%s-endpoints", local.prefix)
  description = "VPC interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https = {
      description = "HTTPS from inside the VPC"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = var.vpc_cidr
    }
  }

  tags = local.tags
}

module "endpoints" {
  source = "../../modules/vpc-endpoints"

  name   = local.prefix
  vpc_id = module.vpc.vpc_id

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.endpoint_sg.id]
  route_table_ids    = values(module.vpc.private_route_table_ids)

  # secretsmanager is load-bearing here: DMS reads its endpoint credentials
  # through it, and its DNS name is passed to the DMS module below.
  interface_services = ["secretsmanager", "logs", "monitoring", "sqs", "kms"]
  gateway_services   = ["s3"]

  tags = local.tags
}
