data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  prefix             = format("%s-%s", var.name, var.environment)

  tags = {
    Environment = var.environment
    Platform    = var.name
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Platform data, logs and images at rest"

  service_principals = [format("logs.%s.amazonaws.com", var.region)]

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

# Image pulls, log writes and secret reads all leave the VPC. Through endpoints
# they never touch the NAT gateway, which is usually the largest line on the bill.
module "endpoints" {
  source = "../../modules/vpc-endpoints"

  name   = local.prefix
  vpc_id = module.vpc.vpc_id

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.endpoint_sg.id]
  route_table_ids    = values(module.vpc.private_route_table_ids)

  # A container pull needs all three: the API, the registry and S3, which is
  # where the layers actually live. Missing any one leaves pulls timing out.
  interface_services = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "ssmmessages"]
  gateway_services   = ["s3"]

  tags = local.tags
}

# --- security groups ---

module "alb_sg" {
  source = "../../modules/security-group"

  name        = format("%s-alb", local.prefix)
  description = "Public load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https = {
      description = "HTTPS from the internet"
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
    }
    http = {
      description = "HTTP from the internet, redirected"
      ip_protocol = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    tasks = {
      description = "Reach the task tier"
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr
    }
  }

  tags = local.tags
}

module "task_sg" {
  source = "../../modules/security-group"

  name        = format("%s-tasks", local.prefix)
  description = "Fargate task network interfaces"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    from_alb = {
      description                  = "Traffic from the load balancer"
      ip_protocol                  = "tcp"
      from_port                    = 1024
      to_port                      = 65535
      referenced_security_group_id = module.alb_sg.id
    }
  }

  tags = local.tags
}

module "database_sg" {
  source = "../../modules/security-group"

  name        = format("%s-database", local.prefix)
  description = "Aurora cluster"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    postgres = {
      description                  = "PostgreSQL from the tasks"
      ip_protocol                  = "tcp"
      from_port                    = 5432
      to_port                      = 5432
      referenced_security_group_id = module.task_sg.id
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
