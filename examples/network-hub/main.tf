data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = coalesce(var.availability_zones, slice(data.aws_availability_zones.available.names, 0, 2))
  prefix             = format("%s-%s", var.name, var.environment)

  all_cidrs = concat([var.shared_vpc_cidr], [for name, spoke in var.spokes : spoke.cidr_block])

  tags = {
    Environment = var.environment
    Network     = var.name
    ManagedBy   = "terraform"
  }
}

# --- shared services VPC, the hub ---

module "shared_vpc" {
  source = "../../modules/vpc"

  name               = format("%s-shared", local.prefix)
  cidr_block         = var.shared_vpc_cidr
  availability_zones = local.availability_zones

  enable_nat_gateway = true
  single_nat_gateway = false

  tags = merge(local.tags, { Tier = "shared" })
}

# --- spokes ---

# No NAT gateway of their own by default. They reach the internet through the
# hub, which is the whole economic argument for this shape.
module "spoke_vpcs" {
  source   = "../../modules/vpc"
  for_each = var.spokes

  name               = format("%s-%s", local.prefix, each.key)
  cidr_block         = each.value.cidr_block
  availability_zones = local.availability_zones

  enable_nat_gateway = each.value.enable_nat_gateway

  tags = merge(local.tags, { Tier = "spoke", Spoke = each.key })
}

# --- the transit gateway ---

module "transit" {
  source = "../../modules/transit-gateway"

  name        = local.prefix
  description = "Hub and spoke routing"

  # Both off, so an attachment is isolated until a route table says otherwise.
  # On, every new attachment silently joins a full mesh.
  default_route_table_association = false
  default_route_table_propagation = false

  route_tables = {
    hub    = "Shared services, reachable by every spoke"
    spokes = "Application VPCs, isolated from each other"
  }

  vpc_attachments = merge(
    {
      shared = {
        vpc_id              = module.shared_vpc.vpc_id
        subnet_ids          = values(module.shared_vpc.private_subnet_ids)
        route_table_key     = "hub"
        propagate_to_tables = ["hub", "spokes"]
      }
    },

    # Each spoke looks up routes in the spokes table, and announces itself only
    # to the hub. Spokes therefore reach shared services and not each other.
    {
      for name, spoke in var.spokes : name => {
        vpc_id              = module.spoke_vpcs[name].vpc_id
        subnet_ids          = values(module.spoke_vpcs[name].private_subnet_ids)
        route_table_key     = "spokes"
        propagate_to_tables = ["hub"]
      }
    }
  )

  tags = local.tags
}

# --- routes into the gateway ---

# A transit gateway attachment does not create routes. Without these, the
# attachment reports available and carries nothing.
resource "aws_route" "shared_to_spokes" {
  for_each = {
    for pair in setproduct(keys(module.shared_vpc.private_route_table_ids), keys(var.spokes)) :
    format("%s-%s", pair[0], pair[1]) => {
      route_table_id = module.shared_vpc.private_route_table_ids[pair[0]]
      destination    = var.spokes[pair[1]].cidr_block
    }
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination
  transit_gateway_id     = module.transit.id

  depends_on = [module.transit]
}

# A spoke sends everything it cannot resolve locally to the hub, which is what
# gives it internet access through the hub's NAT gateways.
resource "aws_route" "spoke_default" {
  for_each = {
    for pair in flatten([
      for name, spoke in var.spokes : [
        for zone, table_id in module.spoke_vpcs[name].private_route_table_ids : {
          key            = format("%s-%s", name, zone)
          route_table_id = table_id
          spoke          = name
        }
      ]
    ]) : pair.key => pair
    if !var.spokes[pair.spoke].enable_nat_gateway
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.transit.id

  depends_on = [module.transit]
}

# --- centralised endpoints ---

module "endpoint_sg" {
  source = "../../modules/security-group"

  name        = format("%s-endpoints", local.prefix)
  description = "Shared VPC interface endpoints"
  vpc_id      = module.shared_vpc.vpc_id

  ingress_rules = {
    for index, cidr in local.all_cidrs : format("net%d", index) => {
      description = format("HTTPS from %s", cidr)
      ip_protocol = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = cidr
    }
  }

  tags = local.tags
}

module "endpoints" {
  source = "../../modules/vpc-endpoints"

  name   = local.prefix
  vpc_id = module.shared_vpc.vpc_id

  subnet_ids         = values(module.shared_vpc.private_subnet_ids)
  security_group_ids = [module.endpoint_sg.id]
  route_table_ids    = values(module.shared_vpc.private_route_table_ids)

  interface_services = var.interface_endpoint_services
  gateway_services   = ["s3", "dynamodb"]

  # Private DNS is disabled so the endpoints can be shared across VPCs through
  # a Route 53 resolver rule. Enabled, the name resolves only in this VPC.
  private_dns_enabled = false

  tags = local.tags
}

# --- on-premises ---

module "vpn_logs" {
  count  = var.on_premises == null ? 0 : 1
  source = "../../modules/cloudwatch-log-group"

  name           = format("/aws/vpn/%s", local.prefix)
  retention_days = 365

  tags = local.tags
}

module "on_premises" {
  count  = var.on_premises == null ? 0 : 1
  source = "../../modules/site-to-site-vpn"

  name                     = format("%s-onprem", local.prefix)
  customer_gateway_ip      = var.on_premises.gateway_ip
  customer_gateway_bgp_asn = var.on_premises.bgp_asn
  transit_gateway_id       = module.transit.id

  static_routes_only = var.on_premises.static_routes_only
  static_routes      = var.on_premises.routes

  log_group_arn = module.vpn_logs[0].arn

  tags = local.tags
}
