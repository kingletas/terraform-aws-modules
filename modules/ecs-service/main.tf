locals {
  tags    = merge(var.tags, { Name = var.name })
  scaling = var.autoscaling
  scale_on = local.scaling == null ? {} : {
    for pair in [
      { key = "cpu", metric = "ECSServiceAverageCPUUtilization", target = local.scaling.cpu_target },
      { key = "memory", metric = "ECSServiceAverageMemoryUtilization", target = local.scaling.memory_target },
      { key = "requests", metric = "ALBRequestCountPerTarget", target = local.scaling.request_target },
    ] : pair.key => pair if pair.target != null
  }

  container_definitions = [
    for name, container in var.containers : {
      name       = name
      image      = container.image
      cpu        = container.cpu
      memory     = container.memory
      essential  = container.essential
      command    = container.command
      entryPoint = container.entrypoint
      user       = container.user

      readonlyRootFilesystem = container.readonly_root_filesystem

      portMappings = [
        for port in container.ports : {
          containerPort = port.container_port
          protocol      = port.protocol
          name          = port.name
        }
      ]

      environment = [
        for key, value in container.environment : { name = key, value = value }
      ]

      secrets = [
        for key, arn in container.secrets : { name = key, valueFrom = arn }
      ]

      dependsOn = [
        for depends_name, condition in container.depends_on_containers :
        { containerName = depends_name, condition = condition }
      ]

      healthCheck = container.health_check_command == null ? null : {
        command  = container.health_check_command
        interval = container.health_check_interval
        retries  = container.health_check_retries
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = name
        }
      }
    }
  ]
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = format("/aws/ecs/%s", var.name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = var.launch_type == null ? ["FARGATE"] : [var.launch_type]

  task_role_arn      = var.task_role_arn
  execution_role_arn = var.execution_role_arn

  container_definitions = jsonencode(local.container_definitions)

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition = var.execution_role_arn != null || alltrue([
        for name, container in var.containers : length(container.secrets) == 0
      ])
      error_message = "Containers naming secrets need an execution_role_arn, because ECS reads them before the task starts."
    }
  }
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = var.launch_type

  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = length(var.load_balancers) > 0 ? var.health_check_grace_period_seconds : null

  deployment_minimum_healthy_percent = var.deployment.minimum_healthy_percent
  deployment_maximum_percent         = var.deployment.maximum_percent

  deployment_circuit_breaker {
    enable   = var.deployment.circuit_breaker
    rollback = var.deployment.circuit_breaker && var.deployment.rollback_on_failure
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  tags = local.tags

  lifecycle {
    # Autoscaling owns the task count once the service is running.
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "this" {
  count = local.scaling == null ? 0 : 1

  service_namespace  = "ecs"
  resource_id        = format("service/%s/%s", reverse(split("/", var.cluster_arn))[0], aws_ecs_service.this.name)
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = local.scaling.min_capacity
  max_capacity       = local.scaling.max_capacity
}

resource "aws_appautoscaling_policy" "this" {
  for_each = local.scale_on

  name               = format("%s-%s", var.name, each.key)
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = each.value.target

    predefined_metric_specification {
      predefined_metric_type = each.value.metric
      resource_label         = each.key == "requests" ? local.scaling.resource_label : null
    }
  }
}
