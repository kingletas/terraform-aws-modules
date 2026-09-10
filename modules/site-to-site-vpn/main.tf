locals {
  use_transit_gateway = var.transit_gateway_id != null
  create_vgw          = var.vpc_id != null
  tags                = merge(var.tags, { Name = var.name })

  tunnel1_inside = try(var.tunnel_inside_cidrs[0], null)
  tunnel2_inside = try(var.tunnel_inside_cidrs[1], null)
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

  vpc_id = var.vpc_id

  tags = local.tags
}

resource "aws_vpn_gateway_route_propagation" "this" {
  for_each = local.create_vgw ? toset(var.propagate_to_route_table_ids) : []

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
      error_message = "Set exactly one of transit_gateway_id or vpc_id."
    }

    precondition {
      condition     = !var.static_routes_only || length(var.static_routes) > 0
      error_message = "Static routing needs at least one entry in static_routes, or nothing reaches the far side."
    }

    precondition {
      condition     = !var.enable_tunnel_logging || var.log_group_arn != null
      error_message = "Tunnel logging needs log_group_arn."
    }
  }
}

resource "aws_vpn_connection_route" "this" {
  for_each = local.create_vgw && var.static_routes_only ? toset(var.static_routes) : []

  vpn_connection_id      = aws_vpn_connection.this.id
  destination_cidr_block = each.value
}
