# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name               = "plan-test"
  security_group_ids = ["sg-0ccccccccccccccc3"]
  master_user_arn    = "arn:aws:iam::123456789012:role/plan-test-search"
}

run "plans_a_domain_in_subnets" {
  command = plan

  variables {
    instance_type = "r7g.large.search"
    subnet_ids    = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  }

  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options) == 1
    error_message = "A domain given subnets should be placed in the VPC."
  }

  assert {
    condition     = aws_opensearch_domain.this.auto_tune_options[0].desired_state == "ENABLED"
    error_message = "Auto-Tune should stay on for an instance type that supports it."
  }
}

run "leaves_auto_tune_out_on_a_t3_instance" {
  command = plan

  variables {
    instance_type = "t3.small.search"
    subnet_ids    = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  }

  assert {
    condition     = local.auto_tune_supported == false
    error_message = "Auto-Tune should be treated as unsupported on T3."
  }
}

run "plans_a_public_domain_when_asked" {
  command = plan

  variables {
    public = true
  }

  assert {
    condition     = length(aws_opensearch_domain.this.vpc_options) == 0
    error_message = "A public domain has no VPC options."
  }
}

run "refuses_a_domain_with_no_placement" {
  command = plan

  expect_failures = [var.public]
}

run "refuses_subnets_on_a_public_domain" {
  command = plan

  variables {
    public     = true
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  }

  expect_failures = [var.public]
}
