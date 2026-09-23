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

run "keys_instances_on_role_and_ordinal_and_names_them_in_full" {
  command = plan

  assert {
    condition     = alltrue([for key in ["admin-01", "builder-01"] : contains(keys(aws_instance.this), key)]) && length(aws_instance.this) == 2
    error_message = "Instances must be keyed by role and ordinal, without the fleet name, so a moved block can name them."
  }

  assert {
    condition     = aws_instance.this["builder-01"].tags["Name"] == "plan-test-builder-01"
    error_message = "The Name tag must still carry the fleet name."
  }

  assert {
    condition     = aws_ebs_volume.this["builder-01-workspace"].tags["Name"] == "plan-test-builder-01-workspace"
    error_message = "A volume's Name tag must still carry the fleet name."
  }

  assert {
    condition     = contains(output.by_role["builder"], "plan-test-builder-01") && length(output.by_role["builder"]) == 1
    error_message = "by_role must still list instances by their full name."
  }
}

run "places_volumes_in_the_subnet_zone" {
  command = plan

  override_data {
    target = data.aws_subnet.volume["builder-01"]
    values = {
      availability_zone = "us-east-1b"
    }
  }

  assert {
    condition     = keys(data.aws_subnet.volume) == ["builder-01"]
    error_message = "Only instances with extra volumes should look up their subnet."
  }

  assert {
    condition     = aws_ebs_volume.this["builder-01-workspace"].availability_zone == "us-east-1b"
    error_message = "An extra volume should take its zone from the subnet, not from the instance it is attached to."
  }

  assert {
    condition     = aws_instance.this["admin-01"].metadata_options[0].instance_metadata_tags == "disabled"
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
    condition     = aws_instance.this["admin-01"].metadata_options[0].instance_metadata_tags == "enabled"
    error_message = "Instance metadata tags should be on when asked for."
  }
}

run "refuses_a_bad_provider_default_tag_key_with_metadata_tags_on" {
  command = plan

  variables {
    instance_metadata_tags = true
  }

  override_data {
    target = data.aws_default_tags.current
    values = {
      tags = { "cost center" = "plan-test" }
    }
  }

  expect_failures = [aws_instance.this]
}

run "accepts_valid_provider_default_tag_keys_with_metadata_tags_on" {
  command = plan

  variables {
    instance_metadata_tags = true
  }

  override_data {
    target = data.aws_default_tags.current
    values = {
      tags = { CostCenter = "plan-test" }
    }
  }

  assert {
    condition     = aws_instance.this["admin-01"].metadata_options[0].instance_metadata_tags == "enabled"
    error_message = "Valid default tag keys should let metadata tags turn on."
  }
}

run "builds_an_instance_holding_a_volume" {
  command = apply

  assert {
    condition     = aws_volume_attachment.this["builder-01-workspace"].stop_instance_before_detaching
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
    condition     = aws_instance.this["builder-01"].ami == "ami-0fedcba9876543210"
    error_message = "Changing the AMI should replace the instance and complete."
  }

  assert {
    condition     = aws_volume_attachment.this["builder-01-workspace"].volume_id == aws_ebs_volume.this["builder-01-workspace"].id
    error_message = "The same extra volume should be attached to the replacement instance."
  }
}
