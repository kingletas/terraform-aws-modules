locals {
  use_transit_gateway = var.transit_gateway_id != null
  create_vgw          = var.vpn_gateway != null
  tags                = merge(var.tags, { Name = var.name })

  tunnel1_inside = try(var.tunnel_inside_cidrs[0], null)
  tunnel2_inside = try(var.tunnel_inside_cidrs[1], null)

  # One route per far-side CIDR in each transit gateway route table that should reach it, keyed by both names.
  transit_gateway_routes = var.static_routes_only ? {
    for pair in setproduct(keys(var.transit_gateway_static_route_tables), keys(var.static_routes)) :
    format("%s-%s", pair[0], pair[1]) => {
      route_table_id         = var.transit_gateway_static_route_tables[pair[0]]
      destination_cidr_block = var.static_routes[pair[1]]
    }
  } : {}

  uses_transit_gateway_routing = (
    var.transit_gateway_association != null ||
    length(var.transit_gateway_propagation_route_tables) > 0 ||
    length(var.transit_gateway_static_route_tables) > 0
  )
}

resource "aws_customer_gateway" "this" {
  type            = "ipsec.1"
  ip_address      = var.customer_gateway_ip
  bgp_asn         = var.customer_gateway_certificate_arn == null ? var.customer_gateway_bgp_asn : null
  certificate_arn = var.customer_gateway_certificate_arn

  tags = local.tags
}

resource "aws_vpn_gateway" "this" {
  count = local.create_vgw ? 1 : 0

  vpc_id = var.vpn_gateway.vpc_id

  tags = local.tags
}

resource "aws_vpn_gateway_route_propagation" "this" {
  for_each = local.create_vgw ? var.vpn_gateway_propagation_route_tables : {}

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = each.value
}

resource "aws_vpn_connection" "this" {
  type                = "ipsec.1"
  customer_gateway_id = aws_customer_gateway.this.id

  transit_gateway_id = var.transit_gateway_id
  vpn_gateway_id     = local.create_vgw ? aws_vpn_gateway.this[0].id : null

  static_routes_only = var.static_routes_only

  local_ipv4_network_cidr  = var.local_ipv4_network_cidr
  remote_ipv4_network_cidr = var.remote_ipv4_network_cidr

  tunnel1_inside_cidr   = local.tunnel1_inside
  tunnel2_inside_cidr   = local.tunnel2_inside
  tunnel1_preshared_key = try(var.tunnel_preshared_keys[0], null)
  tunnel2_preshared_key = try(var.tunnel_preshared_keys[1], null)

  tunnel1_log_options {
    cloudwatch_log_options {
      log_enabled       = var.enable_tunnel_logging
      log_group_arn     = var.log_group_arn
      log_output_format = "json"
    }
  }

  tunnel2_log_options {
    cloudwatch_log_options {
      log_enabled       = var.enable_tunnel_logging
      log_group_arn     = var.log_group_arn
      log_output_format = "json"
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.use_transit_gateway != local.create_vgw
      error_message = "Set exactly one of transit_gateway_id or vpn_gateway."
    }

    precondition {
      condition     = !var.static_routes_only || length(var.static_routes) > 0
      error_message = "Static routing needs at least one entry in static_routes, or nothing reaches the far side."
    }

    precondition {
      condition     = !var.static_routes_only || local.create_vgw || length(var.transit_gateway_static_route_tables) > 0
      error_message = "Static routing through a transit gateway needs transit_gateway_static_route_tables. The routes to the far side live in transit gateway route tables, not on the VPN connection."
    }

    precondition {
      condition     = !local.create_vgw || !local.uses_transit_gateway_routing
      error_message = "transit_gateway_association, transit_gateway_propagation_route_tables and transit_gateway_static_route_tables need transit_gateway_id."
    }

    precondition {
      condition     = local.create_vgw || length(var.vpn_gateway_propagation_route_tables) == 0
      error_message = "vpn_gateway_propagation_route_tables needs vpn_gateway. With a transit gateway, use transit_gateway_propagation_route_tables."
    }

    precondition {
      condition     = !var.enable_tunnel_logging || var.log_group_arn != null
      error_message = "Tunnel logging needs log_group_arn."
    }
  }
}

resource "aws_vpn_connection_route" "this" {
  for_each = local.create_vgw && var.static_routes_only ? var.static_routes : {}

  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = each.value
}

# --- transit gateway routing ---

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  count = local.create_vgw || var.transit_gateway_association == null ? 0 : 1

  transit_gateway_attachment_id  = aws_vpn_connection.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_association.route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.create_vgw ? {} : var.transit_gateway_propagation_route_tables

  transit_gateway_attachment_id  = aws_vpn_connection.this.transit_gateway_attachment_id
  transit_gateway_route_table_id = each.value
}

resource "aws_ec2_transit_gateway_route" "this" {
  for_each = local.create_vgw ? {} : local.transit_gateway_routes

  transit_gateway_route_table_id = each.value.route_table_id
  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_attachment_id  = aws_vpn_connection.this.transit_gateway_attachment_id
}
