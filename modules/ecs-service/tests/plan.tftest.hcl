# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name               = "plan-test"
  cluster_arn        = "arn:aws:ecs:us-east-1:123456789012:cluster/plan-test"
  subnet_ids         = ["subnet-0aaaaaaaaaaaaaaa1"]
  execution_role_arn = "arn:aws:iam::123456789012:role/plan-test-execution"

  containers = {
    app = { image = "public.ecr.aws/example/app:1.0.0" }
  }
}

run "a_fixed_service_follows_desired_count" {
  command = plan

  variables {
    desired_count = 3
  }

  assert {
    condition     = length(aws_ecs_service.this) == 1 && length(aws_ecs_service.autoscaled) == 0
    error_message = "Without autoscaling, only the service whose count Terraform owns should exist."
  }

  assert {
    condition     = aws_ecs_service.this[0].desired_count == 3
    error_message = "The fixed service should run desired_count tasks."
  }
}

run "an_autoscaled_service_hands_its_count_to_the_scaler" {
  command = plan

  variables {
    autoscaling = {
      min_capacity = 2
      max_capacity = 6
      cpu_target   = 60
    }
  }

  assert {
    condition     = length(aws_ecs_service.this) == 0 && length(aws_ecs_service.autoscaled) == 1
    error_message = "With autoscaling, only the service that ignores desired_count should exist."
  }

  assert {
    condition     = aws_appautoscaling_target.this[0].resource_id == "service/plan-test/plan-test"
    error_message = "The scaling target should name the autoscaled service."
  }
}

run "refuses_a_task_without_an_execution_role" {
  command = plan

  variables {
    execution_role_arn = null
  }

  expect_failures = [var.execution_role_arn]
}

run "runs_on_x86_by_default" {
  command = plan

  assert {
    condition     = aws_ecs_task_definition.this.runtime_platform[0].cpu_architecture == "X86_64"
    error_message = "Tasks should run on X86_64 unless another architecture is asked for."
  }
}

run "runs_on_arm_when_asked" {
  command = plan

  variables {
    cpu_architecture = "ARM64"
  }

  assert {
    condition     = aws_ecs_task_definition.this.runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "Tasks should run on the architecture asked for."
  }
}

run "refuses_an_unknown_architecture" {
  command = plan

  variables {
    cpu_architecture = "arm64"
  }

  expect_failures = [var.cpu_architecture]
}

run "runs_on_the_fargate_launch_type_by_default" {
  command = plan

  assert {
    condition     = aws_ecs_service.this[0].launch_type == "FARGATE" && length(aws_ecs_service.this[0].capacity_provider_strategy) == 0
    error_message = "A service with no capacity choice should use the FARGATE launch type and no strategy."
  }
}

run "runs_spot_above_an_on_demand_base" {
  command = plan

  variables {
    capacity = {
      capacity_provider_strategy = [
        { capacity_provider = "FARGATE", base = 1, weight = 1 },
        { capacity_provider = "FARGATE_SPOT", weight = 3 },
      ]
    }
  }

  assert {
    condition     = length(aws_ecs_service.this[0].capacity_provider_strategy) == 2 && aws_ecs_service.this[0].force_new_deployment == true
    error_message = "The service should carry both capacity providers and deploy when the strategy changes."
  }

  assert {
    condition     = aws_ecs_task_definition.this.requires_compatibilities == toset(["FARGATE"])
    error_message = "A Fargate strategy should need a Fargate-compatible task definition."
  }
}

run "an_autoscaled_service_keeps_its_strategy" {
  command = plan

  variables {
    capacity = {
      capacity_provider_strategy = [{ capacity_provider = "FARGATE_SPOT" }]
    }

    autoscaling = {
      min_capacity = 2
      max_capacity = 6
      cpu_target   = 60
    }
  }

  assert {
    condition     = length(aws_ecs_service.autoscaled[0].capacity_provider_strategy) == 1
    error_message = "The autoscaled service should use the strategy."
  }
}

run "refuses_a_launch_type_and_a_strategy_together" {
  command = plan

  variables {
    capacity = {
      launch_type                = "FARGATE"
      capacity_provider_strategy = [{ capacity_provider = "FARGATE_SPOT" }]
    }
  }

  expect_failures = [var.capacity]
}

run "refuses_neither_a_launch_type_nor_a_strategy" {
  command = plan

  variables {
    capacity = {}
  }

  expect_failures = [var.capacity]
}

run "refuses_an_unknown_launch_type" {
  command = plan

  variables {
    capacity = { launch_type = "fargate" }
  }

  expect_failures = [var.capacity]
}

run "refuses_a_base_on_two_providers" {
  command = plan

  variables {
    capacity = {
      capacity_provider_strategy = [
        { capacity_provider = "FARGATE", base = 1 },
        { capacity_provider = "FARGATE_SPOT", base = 1 },
      ]
    }
  }

  expect_failures = [var.capacity]
}

run "refuses_fargate_mixed_with_an_instance_provider" {
  command = plan

  variables {
    capacity = {
      capacity_provider_strategy = [
        { capacity_provider = "FARGATE" },
        { capacity_provider = "plan-test-instances" },
      ]
    }
  }

  expect_failures = [var.capacity]
}
