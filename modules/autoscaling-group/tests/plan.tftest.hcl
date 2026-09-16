# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name                    = "plan-test"
  launch_template_id      = "lt-0123456789abcdef0"
  launch_template_version = "3"
  subnet_ids              = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
}

run "launches_a_numbered_template_version" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.this.launch_template[0].version == "3"
    error_message = "The group should launch the version number it was given, so a new number starts an instance refresh."
  }

  assert {
    condition     = length(aws_autoscaling_group.this.instance_refresh) == 1
    error_message = "Instance refresh should be on by default."
  }
}

run "follows_latest_when_instance_refresh_is_off" {
  command = plan

  variables {
    launch_template_version = "$Latest"
    instance_refresh        = null
  }

  assert {
    condition     = aws_autoscaling_group.this.launch_template[0].version == "$Latest"
    error_message = "Without instance refresh, $Latest should be accepted."
  }
}

run "tracks_a_customized_metric" {
  command = plan

  variables {
    target_tracking_policies = {
      queue = {
        predefined   = false
        target_value = 100
        customized_metric = {
          metric_name = "BacklogPerInstance"
          namespace   = "PlanTest"
          dimensions  = { Queue = "plan-test" }
        }
      }
      cpu = {
        metric_type  = "ASGAverageCPUUtilization"
        target_value = 60
      }
    }
  }

  assert {
    condition     = length(aws_autoscaling_policy.target_tracking["queue"].target_tracking_configuration[0].customized_metric_specification) == 1
    error_message = "A policy with predefined = false should carry a customized metric specification."
  }

  assert {
    condition     = length(aws_autoscaling_policy.target_tracking["queue"].target_tracking_configuration[0].predefined_metric_specification) == 0
    error_message = "A customized policy should carry no predefined metric specification."
  }

  assert {
    condition     = aws_autoscaling_policy.target_tracking["cpu"].target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization"
    error_message = "A predefined policy should name its metric."
  }
}

run "refuses_latest_with_instance_refresh" {
  command = plan

  variables {
    launch_template_version = "$Latest"
  }

  expect_failures = [aws_autoscaling_group.this]
}

run "refuses_a_version_that_is_not_one" {
  command = plan

  variables {
    launch_template_version = "latest"
  }

  expect_failures = [var.launch_template_version]
}

run "refuses_a_predefined_policy_with_no_metric_type" {
  command = plan

  variables {
    target_tracking_policies = {
      cpu = { target_value = 60 }
    }
  }

  expect_failures = [var.target_tracking_policies]
}

run "refuses_a_customized_policy_with_no_metric" {
  command = plan

  variables {
    target_tracking_policies = {
      queue = { predefined = false, target_value = 100 }
    }
  }

  expect_failures = [var.target_tracking_policies]
}
