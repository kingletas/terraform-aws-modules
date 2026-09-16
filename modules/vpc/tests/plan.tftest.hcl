# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name       = "plan-test"
  cidr_block = "10.0.0.0/16"
}

run "plans_two_zones" {
  command = plan

  variables {
    availability_zones = ["us-east-1a", "us-east-1b"]
  }

  assert {
    condition     = aws_subnet.public["us-east-1b"].cidr_block == "10.0.1.0/24"
    error_message = "The second zone's public subnet is not at its letter's position."
  }

  assert {
    condition     = aws_subnet.private["us-east-1b"].cidr_block == "10.0.9.0/24"
    error_message = "The second zone's private subnet is not in the private tier."
  }
}

# Adding a zone must leave every existing zone's subnets where they were.
run "plans_three_zones_without_moving_the_first_two" {
  command = plan

  variables {
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  assert {
    condition     = aws_subnet.public["us-east-1b"].cidr_block == run.plans_two_zones.public_subnet_cidrs["us-east-1b"]
    error_message = "Adding a zone moved an existing public subnet."
  }

  assert {
    condition     = aws_subnet.private["us-east-1b"].cidr_block == run.plans_two_zones.private_subnet_cidrs["us-east-1b"]
    error_message = "Adding a zone moved an existing private subnet."
  }

  assert {
    condition     = aws_subnet.private["us-east-1a"].cidr_block == run.plans_two_zones.private_subnet_cidrs["us-east-1a"]
    error_message = "Adding a zone moved an existing private subnet."
  }

  assert {
    condition     = length(setintersection(values(output.public_subnet_cidrs), values(output.private_subnet_cidrs))) == 0
    error_message = "A public and a private subnet share a range."
  }
}

run "places_a_zone_by_its_letter_not_its_position_in_the_list" {
  command = plan

  variables {
    availability_zones = ["us-east-1c"]
  }

  assert {
    condition     = aws_subnet.public["us-east-1c"].cidr_block == "10.0.2.0/24" && aws_subnet.private["us-east-1c"].cidr_block == "10.0.10.0/24"
    error_message = "A lone zone c was not placed at position 2."
  }
}

run "places_a_local_zone_by_an_explicit_position" {
  command = plan

  variables {
    availability_zones        = ["us-west-2a", "us-west-2-lax-1a"]
    availability_zone_indexes = { "us-west-2-lax-1a" = 7 }
  }

  assert {
    condition     = aws_subnet.private["us-west-2-lax-1a"].cidr_block == "10.0.15.0/24"
    error_message = "The explicit position was not used."
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_two_zones_at_one_position" {
  command = plan

  variables {
    availability_zones = ["us-west-2a", "us-west-2-lax-1a"]
  }

  expect_failures = [var.availability_zones]
}

run "refuses_a_zone_that_no_letter_places" {
  command = plan

  variables {
    availability_zones = ["us-east-1-wl1-bos-wlz-1"]
  }

  expect_failures = [var.availability_zones]
}

run "refuses_more_than_eight_zones" {
  command = plan

  variables {
    availability_zones        = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1e", "us-east-1f", "us-east-1g", "us-east-1h", "us-east-1-lax-1a"]
    availability_zone_indexes = { "us-east-1-lax-1a" = 0 }
  }

  expect_failures = [var.availability_zones]
}

run "refuses_subnets_too_small_for_both_tiers" {
  command = plan

  variables {
    availability_zones = ["us-east-1a"]
    subnet_newbits     = 3
  }

  expect_failures = [var.subnet_newbits]
}
