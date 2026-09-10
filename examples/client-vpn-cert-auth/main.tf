data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # The VPC resolver always answers at the base of the VPC CIDR plus two.
  vpc_resolver = cidrhost(var.vpc_cidr, 2)

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Example     = "client-vpn-cert-auth"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  cidr_block         = var.vpc_cidr
  availability_zones = local.availability_zones
  enable_nat_gateway = false
  tags               = local.tags
}

module "vpn_security_group" {
  source = "../../modules/security-group"

  name        = format("%s-vpn", var.name)
  description = "Client VPN endpoint network interfaces"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    clients = {
      description = "VPN clients reaching the endpoint"
      ip_protocol = "udp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = var.client_cidr_block
    }
  }

  egress_rules = {
    vpc = {
      description = "Reach anything inside the VPC"
      ip_protocol = "-1"
      cidr_ipv4   = var.vpc_cidr
    }
  }

  tags = local.tags
}

module "client_vpn" {
  source = "../../modules/client-vpn"

  name              = var.name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  client_cidr_block = var.client_cidr_block

  security_group_ids = [module.vpn_security_group.id]
  dns_servers        = [local.vpc_resolver]

  server_certificate = {
    certificate_body  = var.server_certificate_body
    private_key       = var.server_private_key
    certificate_chain = var.certificate_chain
  }

  client_root_certificate = {
    certificate_body  = var.client_root_certificate_body
    private_key       = var.client_root_private_key
    certificate_chain = var.certificate_chain
  }

  authorization_rules = {
    vpc = {
      target_network_cidr  = module.vpc.cidr_block
      description          = "Reach the whole VPC"
      authorize_all_groups = true
    }
  }

  tags = local.tags
}
