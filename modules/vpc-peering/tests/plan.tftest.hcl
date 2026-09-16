# Plans the module with IDs from resources created in the same plan, which are
# unknown until apply, which a for_each or count must not depend on.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_ids_unknown_until_apply" {
  command = plan

  module {
    source = "./tests/fixture"
  }

  assert {
    condition     = keys(module.under_test.requester_route_ids) == ["a"] && keys(module.under_test.accepter_route_ids) == ["a"]
    error_message = "Route tables whose IDs are unknown until apply should still get one route each, keyed by name."
  }
}

run "accepts_and_routes_within_one_account_and_region" {
  command = plan

  variables {
    name             = "plan-test"
    requester_vpc_id = "vpc-0aaaaaaaaaaaaaaa1"
    accepter_vpc_id  = "vpc-0bbbbbbbbbbbbbbb2"

    requester_route_table_ids  = { main = "rtb-0aaaaaaaaaaaaaaa1" }
    requester_destination_cidr = "10.1.0.0/16"
  }

  assert {
    condition     = aws_vpc_peering_connection.this.auto_accept && aws_vpc_peering_connection.this.requester[0].allow_remote_vpc_dns_resolution
    error_message = "A same-account, same-region peering should accept itself and resolve remote DNS."
  }

  assert {
    condition     = aws_route.requester["main"].destination_cidr_block == "10.1.0.0/16" && length(aws_route.accepter) == 0
    error_message = "Each requester route table should get a route to the accepter's CIDR."
  }
}

run "leaves_a_cross_account_peering_to_the_accepter" {
  command = plan

  variables {
    name             = "plan-test"
    requester_vpc_id = "vpc-0aaaaaaaaaaaaaaa1"
    accepter_vpc_id  = "vpc-0bbbbbbbbbbbbbbb2"
    peer_owner_id    = "210987654321"
  }

  assert {
    condition     = !aws_vpc_peering_connection.this.auto_accept && length(aws_vpc_peering_connection.this.accepter) == 0
    error_message = "A peering to another account cannot accept itself or set the accepter's options."
  }
}

run "refuses_accepter_routes_across_accounts" {
  command = plan

  variables {
    name             = "plan-test"
    requester_vpc_id = "vpc-0aaaaaaaaaaaaaaa1"
    accepter_vpc_id  = "vpc-0bbbbbbbbbbbbbbb2"
    peer_owner_id    = "210987654321"

    accepter_route_table_ids  = { main = "rtb-0bbbbbbbbbbbbbbb2" }
    accepter_destination_cidr = "10.0.0.0/16"
  }

  expect_failures = [aws_vpc_peering_connection.this]
}
