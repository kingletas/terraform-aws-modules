locals {
  tags                = merge(var.tags, { Name = var.name })
  use_mixed_instances = var.mixed_instances != null
}

resource "aws_autoscaling_group" "this" {
  name_prefix         = format("%s-", var.name)
  vpc_zone_identifier = var.subnet_ids

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  target_group_arns         = var.target_group_arns
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  capacity_rebalance        = var.capacity_rebalance
  termination_policies      = var.termination_policies
  protect_from_scale_in     = var.protect_from_scale_in

  dynamic "launch_template" {
    for_each = local.use_mixed_instances ? [] : [1]

    content {
      id      = var.launch_template_id
      version = var.launch_template_version
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = local.use_mixed_instances ? [var.mixed_instances] : []

    content {
      instances_distribution {
        on_demand_base_capacity                  = mixed_instances_policy.value.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = mixed_instances_policy.value.on_demand_percentage_above_base_capacity
        spot_allocation_strategy                 = mixed_instances_policy.value.spot_allocation_strategy
      }

      launch_template {
        launch_template_specification {
          launch_template_id = var.launch_template_id
          version            = var.launch_template_version
        }

        dynamic "override" {
          for_each = mixed_instances_policy.value.instance_types

          content {
            instance_type = override.value
          }
        }
      }
    }
  }

  dynamic "instance_refresh" {
    for_each = var.instance_refresh == null ? [] : [var.instance_refresh]

    content {
      strategy = instance_refresh.value.strategy

      preferences {
        min_healthy_percentage = instance_refresh.value.min_healthy_percentage
        instance_warmup        = instance_refresh.value.instance_warmup
        auto_rollback          = instance_refresh.value.auto_rollback
      }
    }
  }

  dynamic "warm_pool" {
    for_each = var.warm_pool == null ? [] : [var.warm_pool]

    content {
      pool_state                  = warm_pool.value.pool_state
      min_size                    = warm_pool.value.min_size
      max_group_prepared_capacity = warm_pool.value.max_group_prepared_capacity
    }
  }

  dynamic "tag" {
    for_each = local.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true

    # A scaling policy owns the capacity once the group is running.
    ignore_changes = [desired_capacity]

    precondition {
      condition     = var.instance_refresh == null || can(regex("^[1-9][0-9]*$", var.launch_template_version))
      error_message = "Instance refresh needs launch_template_version to be a version number. $Latest and $Default never change, so a template change would start no refresh, and AWS refuses auto rollback with them."
    }
  }
}

resource "aws_autoscaling_policy" "target_tracking" {
  for_each = var.target_tracking_policies

  name                   = each.key
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value     = each.value.target_value
    disable_scale_in = each.value.disable_scale_in

    dynamic "predefined_metric_specification" {
      for_each = each.value.predefined ? [each.value] : []

      content {
        predefined_metric_type = predefined_metric_specification.value.metric_type
        resource_label         = predefined_metric_specification.value.resource_label
      }
    }

    dynamic "customized_metric_specification" {
      for_each = each.value.predefined ? [] : [each.value.customized_metric]

      content {
        metric_name = customized_metric_specification.value.metric_name
        namespace   = customized_metric_specification.value.namespace
        statistic   = customized_metric_specification.value.statistic
        unit        = customized_metric_specification.value.unit

        dynamic "metric_dimension" {
          for_each = customized_metric_specification.value.dimensions

          content {
            name  = metric_dimension.key
            value = metric_dimension.value
          }
        }
      }
    }
  }
}
