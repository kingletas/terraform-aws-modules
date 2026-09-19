data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = coalesce(var.availability_zones, slice(data.aws_availability_zones.available.names, 0, 2))
  prefix             = format("%s-%s", var.name, var.environment)

  # Every network allowed to reach the shared endpoints, keyed by name so that
  # removing one spoke leaves the other rules alone. The spoke keys carry a
  # prefix, so no spoke name can collide with the shared VPC's own entry.
  endpoint_clients = merge(
    { shared = var.shared_vpc_cidr },
    { for name, spoke in var.spokes : format("spoke-%s", name) => spoke.cidr_block },
  )

  # True when at least one spoke has no NAT gateway and so egresses through the hub.
  egress_through_hub = anytrue([for name, spoke in var.spokes : !spoke.enable_nat_gateway])

  # The spokes table sends unknown traffic to the hub, and drops spoke-to-spoke traffic that would otherwise hairpin through it.
  transit_static_routes = local.egress_through_hub ? merge(
    {
      spokes-default = {
        route_table_key        = "spokes"
        destination_cidr_block = "0.0.0.0/0"
        attachment_key         = "shared"
        blackhole              = false
      }
    },
    {
      for name, spoke in var.spokes : format("spokes-isolate-%s", name) => {
        route_table_key        = "spokes"
        destination_cidr_block = spoke.cidr_block
        attachment_key         = null
        blackhole              = true
      }
    }
  ) : {}

  on_premises_routes = var.on_premises == null ? [] : var.on_premises.routes

  on_premises_route_tables = {
    hub    = module.transit.route_table_ids["hub"]
    spokes = module.transit.route_table_ids["spokes"]
  }

  # On-premises replies look up the hub table, which has learned the shared VPC and every spoke.
  on_premises_association_table = "hub"

  # The far side's ranges reach both tables, by BGP propagation or by static route.
  on_premises_static_routes_only  = try(var.on_premises.static_routes_only, false)
  on_premises_propagation_tables  = local.on_premises_static_routes_only ? {} : local.on_premises_route_tables
  on_premises_static_route_tables = local.on_premises_static_routes_only ? local.on_premises_route_tables : {}

  # A dotted short name such as ecr.api is served at api.ecr.<region>.amazonaws.com.
  endpoint_zone_names = {
    for service in var.interface_endpoint_services :
    service => format("%s.%s.amazonaws.com", join(".", reverse(split(".", service))), var.region)
  }

  # Every VPC that resolves the hub's interface endpoints by their public service names.
  endpoint_zone_vpc_ids = merge(
    { shared = module.shared_vpc.vpc_id },
    { for name, vpc in module.spoke_vpcs : name => vpc.vpc_id },
  )

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

  static_routes = local.transit_static_routes

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

# NAT gateway replies to a spoke leave the public subnets, so the public table needs the way back.
resource "aws_route" "shared_public_to_spokes" {
  for_each = local.egress_through_hub ? var.spokes : {}

  route_table_id         = module.shared_vpc.public_route_table_id
  destination_cidr_block = each.value.cidr_block
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

# The shared private tables default to the NAT gateways, so on-premises ranges need an explicit route.
resource "aws_route" "shared_to_on_premises" {
  for_each = {
    for pair in setproduct(keys(module.shared_vpc.private_route_table_ids), local.on_premises_routes) :
    format("%s-%s", pair[0], pair[1]) => {
      route_table_id = module.shared_vpc.private_route_table_ids[pair[0]]
      destination    = pair[1]
    }
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination
  transit_gateway_id     = module.transit.id

  depends_on = [module.transit]
}

# A spoke with its own NAT gateway defaults to it, so on-premises ranges need an explicit route.
resource "aws_route" "spoke_to_on_premises" {
  for_each = {
    for pair in flatten([
      for name, spoke in var.spokes : [
        for zone_cidr in setproduct(keys(module.spoke_vpcs[name].private_route_table_ids), local.on_premises_routes) : {
          key            = format("%s-%s-%s", name, zone_cidr[0], zone_cidr[1])
          route_table_id = module.spoke_vpcs[name].private_route_table_ids[zone_cidr[0]]
          destination    = zone_cidr[1]
        }
      ] if spoke.enable_nat_gateway
    ]) : pair.key => pair
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination
  transit_gateway_id     = module.transit.id

  depends_on = [module.transit]
}

# A spoke with its own NAT gateway defaults to it, so the shared VPC needs an explicit route.
resource "aws_route" "spoke_to_shared" {
  for_each = {
    for pair in flatten([
      for name, spoke in var.spokes : [
        for zone, table_id in module.spoke_vpcs[name].private_route_table_ids : {
          key            = format("%s-%s", name, zone)
          route_table_id = table_id
        }
      ] if spoke.enable_nat_gateway
    ]) : pair.key => pair
  }

  route_table_id         = each.value.route_table_id
  destination_cidr_block = var.shared_vpc_cidr
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
    for network, cidr in local.endpoint_clients : network => {
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

  # Off, because the private hosted zones below answer for these names in every VPC rather than only this one.
  private_dns_enabled = false

  tags = local.tags
}

# One private zone per service, named as the service's public hostname and associated with the hub and every spoke.
module "endpoint_zones" {
  # checkov:skip=CKV2_AWS_23:Both records alias an interface VPC endpoint, which this check does not count as an attached resource.
  source   = "../../modules/route53-zone"
  for_each = local.endpoint_zone_names

  name            = each.value
  comment         = format("Resolves %s to the shared interface endpoint", each.key)
  private_vpc_ids = values(local.endpoint_zone_vpc_ids)

  # The wildcard covers names addressed below the service, such as <account>.dkr.ecr.
  records = {
    apex = {
      name          = each.value
      type          = "A"
      alias_name    = module.endpoints.interface_dns_names[each.key][0].dns_name
      alias_zone_id = module.endpoints.interface_dns_names[each.key][0].hosted_zone_id
    }
    wildcard = {
      name          = format("*.%s", each.value)
      type          = "A"
      alias_name    = module.endpoints.interface_dns_names[each.key][0].dns_name
      alias_zone_id = module.endpoints.interface_dns_names[each.key][0].hosted_zone_id
    }
  }

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
  static_routes      = { for cidr in var.on_premises.routes : cidr => cidr }

  transit_gateway_association              = { route_table_id = module.transit.route_table_ids[local.on_premises_association_table] }
  transit_gateway_propagation_route_tables = local.on_premises_propagation_tables
  transit_gateway_static_route_tables      = local.on_premises_static_route_tables

  log_group_arn = module.vpn_logs[0].arn

  tags = local.tags
}
