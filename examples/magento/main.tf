data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

# One module decides names, tags and every environment-dependent default, so
# nothing below asks which environment it is in a second time.
module "context" {
  source = "../../modules/context"

  project     = var.project
  environment = var.environment
  owner       = var.owner
  cost_centre = "ecommerce"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  prefix   = module.context.prefix
  tags     = module.context.tags
  defaults = module.context.defaults

  capacity = {
    min     = coalesce(var.web_capacity.min, local.defaults.min_capacity)
    desired = coalesce(var.web_capacity.desired, local.defaults.desired_capacity)
    max     = coalesce(var.web_capacity.max, local.defaults.max_capacity)
  }

  vm_user = "ubuntu"
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Storefront data at rest"

  service_principals = [format("logs.%s.amazonaws.com", var.region)]

  # The alerts topic is encrypted with this key, so its publishers need it too.
  delivery_service_principals = ["cloudwatch.amazonaws.com", "backup.amazonaws.com"]

  deletion_window_in_days = module.context.is_production ? 30 : 7

  tags = local.tags
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.prefix
  cidr_block         = var.vpc_cidr
  availability_zones = local.availability_zones

  enable_nat_gateway = true
  single_nat_gateway = local.defaults.single_nat_gateway

  flow_log_retention_days = local.defaults.log_retention_days
  flow_log_kms_key_arn    = module.kms.arn

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

# ssm, ssmmessages and ec2messages are what let Session Manager reach a private
# instance. They are the reason this stack needs no bastion at all.
module "endpoints" {
  source = "../../modules/vpc-endpoints"

  name   = local.prefix
  vpc_id = module.vpc.vpc_id

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.endpoint_sg.id]
  route_table_ids    = values(module.vpc.private_route_table_ids)

  interface_services = ["ssm", "ssmmessages", "ec2messages", "secretsmanager", "logs"]
  gateway_services   = ["s3"]

  tags = local.tags
}

# --- security groups ---

# CloudFront's origin-facing addresses, the only source the load balancer accepts.
data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  alb_ingress_rules = {
    https = {
      description    = "HTTPS from CloudFront origin-facing servers"
      ip_protocol    = "tcp"
      from_port      = 443
      to_port        = 443
      prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
    }
  }
}

module "alb_sg" {
  source = "../../modules/security-group"

  name        = module.context.name["alb"]
  description = "Storefront load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = local.alb_ingress_rules

  egress_rules = {
    vpc = {
      description = "Reach the application tier"
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr
    }
  }

  tags = local.tags
}

# One group for everything running Magento. The tiers talk to each other
# constantly and share one posture; what separates them is their role, not
# their network position.
module "app_sg" {
  source = "../../modules/security-group"

  name        = format("%s-app", local.prefix)
  description = "Web, cron, admin and builder nodes"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_alb = {
      description                  = "HTTP from the load balancer"
      ip_protocol                  = "tcp"
      from_port                    = 80
      to_port                      = 80
      referenced_security_group_id = module.alb_sg.id
    }

    peers = {
      description = "Nodes reaching each other"
      ip_protocol = "-1"
      self        = true
    }
  }

  tags = local.tags
}

module "datastore_sg" {
  source = "../../modules/security-group"

  name        = module.context.name["data"]
  description = "Database, cache, search and shared media"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    mysql = {
      description                  = "MySQL from the application tier"
      ip_protocol                  = "tcp"
      from_port                    = 3306
      to_port                      = 3306
      referenced_security_group_id = module.app_sg.id
    }
    redis = {
      description                  = "Redis from the application tier"
      ip_protocol                  = "tcp"
      from_port                    = 6379
      to_port                      = 6379
      referenced_security_group_id = module.app_sg.id
    }
    search = {
      description                  = "OpenSearch from the application tier"
      ip_protocol                  = "tcp"
      from_port                    = 443
      to_port                      = 443
      referenced_security_group_id = module.app_sg.id
    }
    nfs = {
      description                  = "NFS for pub/media"
      ip_protocol                  = "tcp"
      from_port                    = 2049
      to_port                      = 2049
      referenced_security_group_id = module.app_sg.id
    }
  }

  tags = local.tags
}
