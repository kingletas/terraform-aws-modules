# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    on_premises = { gateway_ip = "203.0.113.10", static_routes_only = true, routes = ["192.168.0.0/16"] }
  }

  assert {
    condition     = local.transit_static_routes["spokes-default"].destination_cidr_block == "0.0.0.0/0" && local.transit_static_routes["spokes-default"].attachment_key == "shared"
    error_message = "The spokes table must send its default route to the shared VPC attachment."
  }

  assert {
    condition     = local.transit_static_routes["spokes-isolate-production"].blackhole && local.transit_static_routes["spokes-isolate-staging"].blackhole
    error_message = "The spokes table must drop traffic to other spokes, or the default route hairpins it through the hub."
  }

  assert {
    condition     = sort([for route in aws_route.shared_public_to_spokes : route.destination_cidr_block]) == tolist(["10.10.0.0/16", "10.20.0.0/16"])
    error_message = "The shared VPC public route table must route every spoke CIDR back to the transit gateway."
  }

  assert {
    condition     = length(aws_route.shared_to_spokes) == 4
    error_message = "Every shared private route table must route every spoke CIDR to the transit gateway."
  }

  assert {
    condition     = length(module.shared_vpc.nat_gateway_ids) == 2
    error_message = "The hub must carry a NAT gateway per zone for spoke egress."
  }

  assert {
    condition     = keys(local.on_premises_route_tables) == ["hub", "spokes"]
    error_message = "On-premises routes must reach both the hub and spokes tables."
  }

  assert {
    condition     = sort([for route in aws_route.shared_to_on_premises : route.destination_cidr_block]) == tolist(["192.168.0.0/16", "192.168.0.0/16"])
    error_message = "Each shared private route table must route the on-premises range to the transit gateway."
  }
}

run "bgp_still_routes_declared_ranges_from_the_vpcs" {
  command = plan

  variables {
    on_premises = { gateway_ip = "203.0.113.10", bgp_asn = 65010, routes = ["192.168.0.0/16"] }
  }

  assert {
    condition     = sort([for route in aws_route.shared_to_on_premises : route.destination_cidr_block]) == tolist(["192.168.0.0/16", "192.168.0.0/16"])
    error_message = "With BGP, each shared private route table must still route the declared on-premises range to the transit gateway."
  }
}

run "refuses_on_premises_with_no_routes" {
  command = plan

  variables {
    on_premises = { gateway_ip = "203.0.113.10", bgp_asn = 65010 }
  }

  expect_failures = [var.on_premises]
}

run "spokes_with_their_own_nat_skip_hub_egress" {
  command = plan

  variables {
    spokes = {
      production = { cidr_block = "10.10.0.0/16", enable_nat_gateway = true }
    }
    on_premises = { gateway_ip = "203.0.113.10", static_routes_only = true, routes = ["192.168.0.0/16"] }
  }

  assert {
    condition     = length(local.transit_static_routes) == 0 && length(aws_route.shared_public_to_spokes) == 0 && length(aws_route.spoke_default) == 0
    error_message = "No spoke egresses through the hub, so no hub egress routes should exist."
  }

  assert {
    condition     = length(aws_route.spoke_to_on_premises) == 2
    error_message = "A spoke with its own NAT gateway needs an explicit route to on-premises in each private table."
  }
}
