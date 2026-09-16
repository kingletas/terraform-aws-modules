# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name = "plan-test"

  defaults = {
    ami_id     = "ami-0123456789abcdef0"
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  }

  roles = {
    builder = {
      extra_volumes = {
        workspace = { device_name = "/dev/sdf", size = 50 }
      }
    }
    admin = {}
  }
}

run "places_volumes_in_the_subnet_zone" {
  command = plan

  override_data {
    target = data.aws_subnet.volume["plan-test-builder-01"]
    values = {
      availability_zone = "us-east-1b"
    }
  }

  assert {
    condition     = keys(data.aws_subnet.volume) == ["plan-test-builder-01"]
    error_message = "Only instances with extra volumes should look up their subnet."
  }

  assert {
    condition     = aws_ebs_volume.this["plan-test-builder-01-workspace"].availability_zone == "us-east-1b"
    error_message = "An extra volume should take its zone from the subnet, not from the instance it is attached to."
  }

  assert {
    condition     = aws_instance.this["plan-test-admin-01"].metadata_options[0].instance_metadata_tags == "disabled"
    error_message = "Instance metadata tags should be off unless asked for."
  }
}

run "refuses_a_space_in_a_tag_key_with_metadata_tags_on" {
  command = plan

  variables {
    instance_metadata_tags = true
    tags                   = { "Cost Center" = "plan-test" }
  }

  expect_failures = [aws_instance.this]
}

run "accepts_valid_tag_keys_with_metadata_tags_on" {
  command = plan

  variables {
    instance_metadata_tags = true
    tags                   = { Environment = "plan-test" }
  }

  assert {
    condition     = aws_instance.this["plan-test-admin-01"].metadata_options[0].instance_metadata_tags == "enabled"
    error_message = "Instance metadata tags should be on when asked for."
  }
}

run "builds_an_instance_holding_a_volume" {
  command = apply

  assert {
    condition     = aws_volume_attachment.this["plan-test-builder-01-workspace"].stop_instance_before_detaching
    error_message = "Detaching an extra volume should stop the instance first."
  }
}

run "replaces_an_instance_holding_a_volume" {
  command = apply

  variables {
    defaults = {
      ami_id     = "ami-0fedcba9876543210"
      subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
    }
  }

  assert {
    condition     = aws_instance.this["plan-test-builder-01"].ami == "ami-0fedcba9876543210"
    error_message = "Changing the AMI should replace the instance and complete."
  }

  assert {
    condition     = aws_volume_attachment.this["plan-test-builder-01-workspace"].volume_id == aws_ebs_volume.this["plan-test-builder-01-workspace"].id
    error_message = "The same extra volume should be attached to the replacement instance."
  }
}
