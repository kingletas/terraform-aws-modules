data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  prefix             = format("%s-%s", var.name, var.environment)

  tags = {
    Environment = var.environment
    Pipeline    = var.name
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Warehouse data at rest"

  service_principals = [format("logs.%s.amazonaws.com", var.region)]

  # CloudWatch publishes alarms to the encrypted topic and EventBridge sends missed runs to the encrypted queue.
  delivery_service_principals = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]

  tags = local.tags
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.prefix
  cidr_block         = var.vpc_cidr
  availability_zones = local.availability_zones

  enable_nat_gateway = true

  # A batch pipeline runs for an hour a day. Paying for a NAT gateway per zone
  # around the clock to protect a job that can simply be re-run is the wrong trade.
  single_nat_gateway = true

  flow_log_kms_key_arn = module.kms.arn

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

  interface_services = ["secretsmanager", "logs", "states", "sqs"]
  gateway_services   = ["s3", "dynamodb"]

  tags = local.tags
}

module "job_sg" {
  source = "../../modules/security-group"

  name        = format("%s-jobs", local.prefix)
  description = "Extraction and transform jobs"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {}

  tags = local.tags
}

# --- the three zones of the lake ---

# Raw is what arrived, unmodified. Keeping it is what lets you fix a transform
# bug without going back to a source system that may not hold the history.
module "raw" {
  source = "../../modules/s3-bucket"

  name        = format("%s-raw-%s", local.prefix, data.aws_caller_identity.current.account_id)
  kms_key_arn = module.kms.arn

  lifecycle_rules = {
    age_out = {
      transition_days          = 30
      transition_storage_class = "STANDARD_IA"
      expiration_days          = var.raw_retention_days
    }
  }

  tags = merge(local.tags, { Zone = "raw" })
}

module "curated" {
  source = "../../modules/s3-bucket"

  name        = format("%s-curated-%s", local.prefix, data.aws_caller_identity.current.account_id)
  kms_key_arn = module.kms.arn

  lifecycle_rules = var.curated_retention_days > 0 ? {
    age_out = {
      transition_days          = 90
      transition_storage_class = "STANDARD_IA"
      expiration_days          = var.curated_retention_days
    }
  } : {}

  tags = merge(local.tags, { Zone = "curated" })
}

# --- source credentials, created empty ---

# The container exists and the password does not pass through Terraform. Write
# each value with the CLI after the first apply.
module "source_credentials" {
  source   = "../../modules/secrets-manager-secret"
  for_each = var.sources

  name        = format("%s/%s/source/%s", var.name, var.environment, each.key)
  description = coalesce(each.value.description, format("Credentials for the %s source", each.key))
  kms_key_arn = module.kms.arn

  tags = merge(local.tags, { Source = each.key })
}

# --- run state ---

# One row per source per run. This is what makes a re-run idempotent and what
# answers "did last night's load actually finish".
module "run_ledger" {
  source = "../../modules/dynamodb-table"

  name      = format("%s-runs", local.prefix)
  hash_key  = "source"
  range_key = "run_started_at"

  attributes = [
    { name = "source", type = "S" },
    { name = "run_started_at", type = "N" },
    { name = "status", type = "S" },
  ]

  global_secondary_indexes = {
    by_status = {
      hash_key        = "status"
      range_key       = "run_started_at"
      projection_type = "KEYS_ONLY"
    }
  }

  kms_key_arn = module.kms.arn

  tags = local.tags
}
