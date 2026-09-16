# Plans the module on its own with real values. Nothing is created. No run sets
# security_group_ids, so every plan also proves an empty list is left unset.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name                              = "plan-test"
  vpc_id                            = "vpc-0aaaaaaaaaaaaaaa1"
  subnet_ids                        = { us-east-1a = "subnet-0aaaaaaaaaaaaaaa1" }
  server_certificate_arn            = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000001"
  client_root_certificate_chain_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000002"

  authorization_rules = {
    vpc = { target_network_cidr = "10.0.0.0/16", authorize_all_groups = true }
  }
}

run "plans_the_largest_pool_aws_accepts" {
  command = plan

  variables {
    client_cidr_block = "10.96.0.0/12"
  }

  assert {
    condition     = aws_ec2_client_vpn_endpoint.this.client_cidr_block == "10.96.0.0/12"
    error_message = "A /12 pool is within the range AWS accepts."
  }
}

run "plans_the_smallest_pool_aws_accepts" {
  command = plan

  variables {
    client_cidr_block = "10.100.0.0/22"
  }
}

run "refuses_a_pool_larger_than_a_12" {
  command = plan

  variables {
    client_cidr_block = "10.0.0.0/8"
  }

  expect_failures = [var.client_cidr_block]
}

run "refuses_a_pool_smaller_than_a_22" {
  command = plan

  variables {
    client_cidr_block = "10.100.0.0/24"
  }

  expect_failures = [var.client_cidr_block]
}
