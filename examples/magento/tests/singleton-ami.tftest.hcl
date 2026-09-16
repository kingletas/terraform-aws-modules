# Applies the singletons' AMI pin twice against mock providers to prove a new ami_id leaves it alone.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "aws" {
  alias  = "us_east_1"
  source = "../../testing/mocks"
}

mock_provider "local" {}
mock_provider "random" {}

variables {
  domain_name      = "shop.example.com"
  hosted_zone_name = "example.com"
}

run "builds_the_singletons_from_the_first_ami" {
  plan_options {
    target = [terraform_data.singleton_ami]
  }

  variables {
    ami_id = "ami-0123456789abcdef0"
  }

  assert {
    condition     = terraform_data.singleton_ami.output == "ami-0123456789abcdef0"
    error_message = "The singletons should be built from the AMI given at creation."
  }
}

run "a_new_ami_leaves_the_singletons_on_the_old_one" {
  plan_options {
    target = [terraform_data.singleton_ami]
  }

  variables {
    ami_id = "ami-0fedcba9876543210"
  }

  assert {
    condition     = terraform_data.singleton_ami.output == "ami-0123456789abcdef0"
    error_message = "A new ami_id must not change the singletons' AMI in the same apply."
  }
}
