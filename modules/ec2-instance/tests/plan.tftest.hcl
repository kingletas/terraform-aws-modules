# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name           = "plan-test"
  ami_id         = "ami-0123456789abcdef0"
  instance_count = 2
  subnet_ids     = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
}

run "looks_up_no_subnet_without_extra_volumes" {
  command = plan

  assert {
    condition     = length(data.aws_subnet.volume) == 0
    error_message = "Without extra volumes, no subnet should be looked up."
  }

  assert {
    condition     = aws_instance.this["plan-test-01"].metadata_options[0].instance_metadata_tags == "disabled"
    error_message = "Instance metadata tags should be off unless asked for."
  }
}

run "places_volumes_in_the_subnet_zone" {
  command = plan

  variables {
    extra_volumes = {
      data = { device_name = "/dev/sdf", size = 50 }
    }
  }

  override_data {
    target = data.aws_subnet.volume["plan-test-02"]
    values = {
      availability_zone = "us-east-1b"
    }
  }

  assert {
    condition     = data.aws_subnet.volume["plan-test-02"].id == "subnet-0bbbbbbbbbbbbbbb2"
    error_message = "Each instance should look up the subnet it launches into."
  }

  assert {
    condition     = aws_ebs_volume.this["plan-test-02-data"].availability_zone == "us-east-1b"
    error_message = "An extra volume should take its zone from the subnet, not from the instance it is attached to."
  }
}

run "refuses_a_slash_in_a_tag_key_with_metadata_tags_on" {
  command = plan

  variables {
    instance_metadata_tags = true
    tags                   = { "team/owner" = "plan-test" }
  }

  expect_failures = [aws_instance.this]
}

run "builds_an_instance_holding_a_volume" {
  command = apply

  variables {
    extra_volumes = {
      data = { device_name = "/dev/sdf", size = 50 }
    }
  }

  assert {
    condition     = aws_volume_attachment.this["plan-test-01-data"].stop_instance_before_detaching
    error_message = "Detaching an extra volume should stop the instance first."
  }
}

run "replaces_an_instance_holding_a_volume" {
  command = apply

  variables {
    ami_id = "ami-0fedcba9876543210"
    extra_volumes = {
      data = { device_name = "/dev/sdf", size = 50 }
    }
  }

  assert {
    condition     = aws_instance.this["plan-test-01"].ami == "ami-0fedcba9876543210"
    error_message = "Changing the AMI should replace the instance and complete."
  }

  assert {
    condition     = aws_volume_attachment.this["plan-test-01-data"].volume_id == aws_ebs_volume.this["plan-test-01-data"].id
    error_message = "The same extra volume should be attached to the replacement instance."
  }
}
