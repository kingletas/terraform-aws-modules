variable "name" {
  type        = string
  description = "Name prefix for the autoscaling group."
}

variable "launch_template_id" {
  type        = string
  description = "Launch template to launch instances from."
}

variable "launch_template_version" {
  type        = string
  description = "Version number to launch, usually the launch-template module's latest_version output. A new number is what starts an instance refresh. $Latest and $Default are accepted only with instance_refresh set to null, because they never change and AWS refuses auto rollback with them."

  validation {
    condition     = can(regex("^([1-9][0-9]*|\\$Latest|\\$Default)$", var.launch_template_version))
    error_message = "The launch_template_version must be a version number, $Latest or $Default."
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets to launch into. Spread across availability zones so a zone failure is survivable."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "min_size" {
  type        = number
  description = "Fewest instances to keep running."
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Most instances to allow."
  default     = 6
}

variable "desired_capacity" {
  type        = number
  description = "Instances to run now. Null lets a scaling policy own it, which stops Terraform fighting the scaler."
  default     = null
}

variable "target_group_arns" {
  type        = list(string)
  description = "Load balancer target groups to register instances with."
  default     = []
}

variable "health_check_type" {
  type        = string
  description = "EC2 replaces an instance only when the hypervisor says it is gone. ELB also replaces one the load balancer calls unhealthy."
  default     = "ELB"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "The health_check_type must be EC2 or ELB."
  }
}

variable "health_check_grace_period" {
  type        = number
  description = "Seconds after launch before health checks count. Set it above your boot and warm-up time or healthy instances get killed."
  default     = 300
}

variable "capacity_rebalance" {
  type        = bool
  description = "Replace a spot instance before AWS reclaims it, rather than after."
  default     = true
}

variable "mixed_instances" {
  type = object({
    on_demand_base_capacity                  = optional(number, 1)
    on_demand_percentage_above_base_capacity = optional(number, 0)
    spot_allocation_strategy                 = optional(string, "price-capacity-optimized")
    instance_types                           = optional(list(string), [])
  })
  description = "Mix on-demand and spot capacity. Null launches only on-demand instances of the template's type."
  default     = null
}

variable "instance_refresh" {
  type = object({
    strategy               = optional(string, "Rolling")
    min_healthy_percentage = optional(number, 90)
    instance_warmup        = optional(number)
    auto_rollback          = optional(bool, true)
  })
  description = "Roll instances automatically when the launch template changes. Null leaves existing instances on the old version."
  default     = {}
}

variable "target_tracking_policies" {
  type = map(object({
    metric_type      = optional(string)
    target_value     = number
    predefined       = optional(bool, true)
    resource_label   = optional(string)
    disable_scale_in = optional(bool, false)

    customized_metric = optional(object({
      metric_name = string
      namespace   = string
      statistic   = optional(string, "Average")
      unit        = optional(string)
      dimensions  = optional(map(string), {})
    }))
  }))
  description = "Target tracking scaling policies keyed by name. A predefined policy names metric_type, such as ASGAverageCPUUtilization; a policy with predefined = false names customized_metric instead."
  default     = {}

  validation {
    condition = alltrue([
      for name, policy in var.target_tracking_policies :
      policy.predefined ? (policy.metric_type != null && policy.customized_metric == null) : (policy.customized_metric != null && policy.metric_type == null && policy.resource_label == null)
    ])
    error_message = "A predefined policy needs metric_type and no customized_metric. A policy with predefined = false needs customized_metric, and takes neither metric_type nor resource_label."
  }
}

variable "warm_pool" {
  type = object({
    pool_state                  = optional(string, "Stopped")
    min_size                    = optional(number, 0)
    max_group_prepared_capacity = optional(number)
  })
  description = "Keep pre-initialised instances stopped and ready, for workloads whose boot is slow. Null disables the pool."
  default     = null
}

variable "termination_policies" {
  type        = list(string)
  description = "Order instances are chosen for termination in."
  default     = ["OldestLaunchTemplate", "OldestInstance"]
}

variable "protect_from_scale_in" {
  type        = bool
  description = "Stop the scaler terminating instances. Use for a group whose instances drain work before exiting."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the group and propagated to its instances."
  default     = {}
}
