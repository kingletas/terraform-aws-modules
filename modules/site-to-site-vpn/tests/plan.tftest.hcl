# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name                = "plan-test"
  customer_gateway_ip = "203.0.113.10"
  log_group_arn       = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/vpn/plan-test"
}

run "plans_static_routes_into_transit_gateway_route_tables" {
  command = plan

  variables {
    transit_gateway_id = "tgw-0aaaaaaaaaaaaaaa1"

    static_routes_only = true
    static_routes      = { office = "192.168.0.0/16", warehouse = "172.16.0.0/12" }

    transit_gateway_association = { route_table_id = "tgw-rtb-0aaaaaaaaaaaaaaa1" }

    transit_gateway_static_route_tables = {
      hub    = "tgw-rtb-0aaaaaaaaaaaaaaa1"
      spokes = "tgw-rtb-0bbbbbbbbbbbbbbb2"
    }

    transit_gateway_propagation_route_tables = {
      hub = "tgw-rtb-0aaaaaaaaaaaaaaa1"
    }
  }

  assert {
    condition = toset(keys(aws_ec2_transit_gateway_route.this)) == toset([
      "hub-office", "hub-warehouse", "spokes-office", "spokes-warehouse",
    ])
    error_message = "Every far-side CIDR needs a route in every named transit gateway route table."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.this["spokes-warehouse"].transit_gateway_route_table_id == "tgw-rtb-0bbbbbbbbbbbbbbb2" && aws_ec2_transit_gateway_route.this["spokes-warehouse"].destination_cidr_block == "172.16.0.0/12"
    error_message = "A route landed in the wrong transit gateway route table."
  }

  assert {
    condition     = aws_ec2_transit_gateway_route_table_association.this[0].transit_gateway_route_table_id == "tgw-rtb-0aaaaaaaaaaaaaaa1"
    error_message = "The VPN attachment was not associated with the named route table."
  }

  assert {
    condition     = keys(aws_ec2_transit_gateway_route_table_propagation.this) == ["hub"]
    error_message = "The VPN attachment was not propagated into the named route table."
  }

  assert {
    condition     = length(aws_vpn_connection_route.this) == 0
    error_message = "A VPN connection route was planned for a transit gateway attachment."
  }
}

run "plans_a_virtual_private_gateway_with_keyed_propagation" {
  command = plan

  variables {
    vpn_gateway = { vpc_id = "vpc-0aaaaaaaaaaaaaaa1" }

    static_routes_only = true
    static_routes      = { office = "192.168.0.0/16" }

    vpn_gateway_propagation_route_tables = {
      a = "rtb-0aaaaaaaaaaaaaaa1"
      b = "rtb-0bbbbbbbbbbbbbbb2"
    }
  }

  assert {
    condition     = toset(keys(aws_vpn_gateway_route_propagation.this)) == toset(["a", "b"])
    error_message = "Propagation is not keyed by the caller's names."
  }

  assert {
    condition     = keys(aws_vpn_connection_route.this) == ["office"] && aws_vpn_connection_route.this["office"].destination_cidr_block == "192.168.0.0/16"
    error_message = "The static route was not planned on the VPN connection."
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route.this) == 0 && length(aws_ec2_transit_gateway_route_table_association.this) == 0
    error_message = "Transit gateway routing was planned for a virtual private gateway."
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_static_routes_through_a_transit_gateway_with_no_route_table" {
  command = plan

  variables {
    transit_gateway_id = "tgw-0aaaaaaaaaaaaaaa1"
    static_routes_only = true
    static_routes      = { office = "192.168.0.0/16" }
  }

  expect_failures = [aws_vpn_connection.this]
}

run "refuses_transit_gateway_routing_on_a_virtual_private_gateway" {
  command = plan

  variables {
    vpn_gateway                 = { vpc_id = "vpc-0aaaaaaaaaaaaaaa1" }
    transit_gateway_association = { route_table_id = "tgw-rtb-0aaaaaaaaaaaaaaa1" }
  }

  expect_failures = [aws_vpn_connection.this]
}

run "refuses_vpn_gateway_propagation_on_a_transit_gateway" {
  command = plan

  variables {
    transit_gateway_id                   = "tgw-0aaaaaaaaaaaaaaa1"
    vpn_gateway_propagation_route_tables = { a = "rtb-0aaaaaaaaaaaaaaa1" }
  }

  expect_failures = [aws_vpn_connection.this]
}

run "refuses_a_static_route_that_is_not_a_cidr" {
  command = plan

  variables {
    vpn_gateway        = { vpc_id = "vpc-0aaaaaaaaaaaaaaa1" }
    static_routes_only = true
    static_routes      = { office = "192.168.0.0" }
  }

  expect_failures = [var.static_routes]
}
