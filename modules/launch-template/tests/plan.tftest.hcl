# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name     = "plan-test"
  image_id = "ami-0123456789abcdef0"
}

run "takes_the_root_device_from_the_ami" {
  command = plan

  override_data {
    target = data.aws_ami.this
    values = {
      root_device_name = "/dev/sda1"
    }
  }

  assert {
    condition     = aws_launch_template.this.block_device_mappings[0].device_name == "/dev/sda1"
    error_message = "The root volume settings should land on the AMI's own root device."
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].instance_metadata_tags == "disabled"
    error_message = "Instance metadata tags should be off unless asked for."
  }
}

run "uses_a_root_device_name_the_caller_gives" {
  command = plan

  variables {
    root_volume = { device_name = "/dev/xvda" }
  }

  assert {
    condition     = aws_launch_template.this.block_device_mappings[0].device_name == "/dev/xvda"
    error_message = "A root device name the caller supplies should win over the AMI lookup."
  }
}

run "exposes_metadata_tags_with_valid_keys" {
  command = plan

  variables {
    instance_metadata_tags = true
    tags                   = { Environment = "plan-test", "cost:center" = "plan-test" }
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].instance_metadata_tags == "enabled"
    error_message = "Instance metadata tags should be on when asked for."
  }
}

run "refuses_a_slash_in_a_tag_key_with_metadata_tags_on" {
  command = plan

  variables {
    instance_metadata_tags = true
    tags                   = { "kubernetes.io/cluster/plan-test" = "owned" }
  }

  expect_failures = [aws_launch_template.this]
}

run "accepts_a_slash_in_a_tag_key_with_metadata_tags_off" {
  command = plan

  variables {
    tags = { "kubernetes.io/cluster/plan-test" = "owned" }
  }
}
