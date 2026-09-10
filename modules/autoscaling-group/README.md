# autoscaling-group

An autoscaling group with instance refresh and target tracking, spread across the subnets you give it.

## Usage

```hcl
module "app" {
  source = "github.com/kingletas/terraform-aws-modules//modules/autoscaling-group?ref=v0.1.0"

  name               = "platform-app"
  launch_template_id = module.app_template.id
  subnet_ids         = values(module.vpc.private_subnet_ids)

  min_size = 3
  max_size = 12

  target_group_arns = [module.alb.target_group_arns["app"]]

  target_tracking_policies = {
    cpu = {
      metric_type  = "ASGAverageCPUUtilization"
      target_value = 60
    }
  }
}
```

## Terraform does not own the instance count

`desired_capacity` is in `ignore_changes`. Once a scaling policy exists it owns that number, and without this Terraform would set it back on every apply — undoing a scale-out, sometimes in the middle of the traffic that caused it.

## Notes

- **`health_check_grace_period` must exceed your boot and warm-up time.** Set it too low with `health_check_type = "ELB"` and the group kills healthy instances before they finish starting, then launches replacements that meet the same fate.
- `instance_refresh` rolls instances when the launch template changes. Without it, existing instances stay on the old version indefinitely and nothing says so.
- `mixed_instances` buys spot capacity. `on_demand_base_capacity` is the floor that stays on-demand whatever the spot market does.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.target_tracking](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the autoscaling group. | `string` | n/a | yes |
| launch\_template\_id | Launch template to launch instances from. | `string` | n/a | yes |
| launch\_template\_version | Version to launch. $Latest follows every template change; $Default follows the template's own default. | `string` | `"$Latest"` | no |
| subnet\_ids | Subnets to launch into. Spread across availability zones so a zone failure is survivable. | `list(string)` | n/a | yes |
| min\_size | Fewest instances to keep running. | `number` | `2` | no |
| max\_size | Most instances to allow. | `number` | `6` | no |
| desired\_capacity | Instances to run now. Null lets a scaling policy own it, which stops Terraform fighting the scaler. | `number` | `null` | no |
| target\_group\_arns | Load balancer target groups to register instances with. | `list(string)` | `[]` | no |
| health\_check\_type | EC2 replaces an instance only when the hypervisor says it is gone. ELB also replaces one the load balancer calls unhealthy. | `string` | `"ELB"` | no |
| health\_check\_grace\_period | Seconds after launch before health checks count. Set it above your boot and warm-up time or healthy instances get killed. | `number` | `300` | no |
| capacity\_rebalance | Replace a spot instance before AWS reclaims it, rather than after. | `bool` | `true` | no |
| mixed\_instances | Mix on-demand and spot capacity. Null launches only on-demand instances of the template's type. | <pre>object({<br/>    on_demand_base_capacity                  = optional(number, 1)<br/>    on_demand_percentage_above_base_capacity = optional(number, 0)<br/>    spot_allocation_strategy                 = optional(string, "price-capacity-optimized")<br/>    instance_types                           = optional(list(string), [])<br/>  })</pre> | `null` | no |
| instance\_refresh | Roll instances automatically when the launch template changes. Null leaves existing instances on the old version. | <pre>object({<br/>    strategy               = optional(string, "Rolling")<br/>    min_healthy_percentage = optional(number, 90)<br/>    instance_warmup        = optional(number)<br/>    auto_rollback          = optional(bool, true)<br/>  })</pre> | `{}` | no |
| target\_tracking\_policies | Target tracking scaling policies keyed by name. metric\_type is a predefined metric such as ASGAverageCPUUtilization. | <pre>map(object({<br/>    metric_type      = optional(string)<br/>    target_value     = number<br/>    predefined       = optional(bool, true)<br/>    resource_label   = optional(string)<br/>    disable_scale_in = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| warm\_pool | Keep pre-initialised instances stopped and ready, for workloads whose boot is slow. Null disables the pool. | <pre>object({<br/>    pool_state                  = optional(string, "Stopped")<br/>    min_size                    = optional(number, 0)<br/>    max_group_prepared_capacity = optional(number)<br/>  })</pre> | `null` | no |
| termination\_policies | Order instances are chosen for termination in. | `list(string)` | <pre>[<br/>  "OldestLaunchTemplate",<br/>  "OldestInstance"<br/>]</pre> | no |
| protect\_from\_scale\_in | Stop the scaler terminating instances. Use for a group whose instances drain work before exiting. | `bool` | `false` | no |
| tags | Tags applied to the group and propagated to its instances. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| name | Generated name of the autoscaling group. |
| arn | ARN of the autoscaling group. |
| id | ID of the autoscaling group, which is the same as its name. |
| availability\_zones | Availability zones the group launches into. |
| scaling\_policy\_arns | Scaling policy ARNs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
