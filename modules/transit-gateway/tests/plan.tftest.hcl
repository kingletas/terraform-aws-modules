# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name = "plan-test"

  route_tables = {
    hub    = "Shared services"
    spokes = "Application VPCs"
  }
}

run "plans_segmented_attachments" {
  command = plan

  variables {
    vpc_attachments = {
      shared = {
        vpc_id              = "vpc-0aaaaaaaaaaaaaaa1"
        subnet_ids          = ["subnet-0aaaaaaaaaaaaaaa1"]
        route_table_key     = "hub"
        propagate_to_tables = ["hub", "spokes"]
      }
    }
  }

  assert {
    condition     = keys(aws_ec2_transit_gateway_route_table_association.this) == ["shared"]
    error_message = "The attachment was not associated with its named table."
  }
}

run "plans_default_association_without_explicit_tables" {
  command = plan

  variables {
    default_route_table_association = true

    vpc_attachments = {
      shared = {
        vpc_id     = "vpc-0aaaaaaaaaaaaaaa1"
        subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1"]
      }
    }
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table_association.this) == 0
    error_message = "An explicit association was planned alongside the default one."
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_an_explicit_association_with_default_association_on" {
  command = plan

  variables {
    default_route_table_association = true

    vpc_attachments = {
      shared = {
        vpc_id          = "vpc-0aaaaaaaaaaaaaaa1"
        subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1"]
        route_table_key = "hub"
      }
    }
  }

  expect_failures = [var.vpc_attachments]
}

run "plans_a_forwarding_route_and_a_blackhole" {
  command = plan

  variables {
    vpc_attachments = {
      shared = {
        vpc_id          = "vpc-0aaaaaaaaaaaaaaa1"
        subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1"]
        route_table_key = "hub"
      }
    }

    static_routes = {
      default = { route_table_key = "spokes", destination_cidr_block = "0.0.0.0/0", attachment_key = "shared" }
      drop    = { route_table_key = "spokes", destination_cidr_block = "10.99.0.0/16", blackhole = true }
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.this["drop"].blackhole && aws_ec2_transit_gateway_route.this["drop"].transit_gateway_attachment_id == null
    error_message = "A blackhole route should name no attachment."
  }

  assert {
    condition     = !aws_ec2_transit_gateway_route.this["default"].blackhole
    error_message = "A route with an attachment should forward traffic."
  }
}

run "refuses_a_forwarding_route_with_no_attachment" {
  command = plan

  variables {
    static_routes = {
      default = { route_table_key = "spokes", destination_cidr_block = "0.0.0.0/0" }
    }
  }

  expect_failures = [var.static_routes]
}

run "refuses_a_blackhole_route_that_names_an_attachment" {
  command = plan

  variables {
    vpc_attachments = {
      shared = {
        vpc_id          = "vpc-0aaaaaaaaaaaaaaa1"
        subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1"]
        route_table_key = "hub"
      }
    }

    static_routes = {
      drop = { route_table_key = "spokes", destination_cidr_block = "10.99.0.0/16", attachment_key = "shared", blackhole = true }
    }
  }

  expect_failures = [var.static_routes]
}

run "refuses_a_route_into_an_unknown_route_table" {
  command = plan

  variables {
    static_routes = {
      drop = { route_table_key = "nowhere", destination_cidr_block = "10.99.0.0/16", blackhole = true }
    }
  }

  expect_failures = [var.static_routes]
}
