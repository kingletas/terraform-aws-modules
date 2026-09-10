variable "name" {
  type        = string
  description = "Service name, also used for the task definition family and the log group."
}

variable "cluster_arn" {
  type        = string
  description = "Cluster to run in."
}

variable "containers" {
  type = map(object({
    image      = string
    cpu        = optional(number)
    memory     = optional(number)
    essential  = optional(bool, true)
    command    = optional(list(string))
    entrypoint = optional(list(string))

    ports = optional(list(object({
      container_port = number
      protocol       = optional(string, "tcp")
      name           = optional(string)
    })), [])

    environment = optional(map(string), {})
    secrets     = optional(map(string), {})

    health_check_command  = optional(list(string))
    health_check_interval = optional(number, 30)
    health_check_retries  = optional(number, 3)

    readonly_root_filesystem = optional(bool, true)
    user                     = optional(string)
    depends_on_containers    = optional(map(string), {})
  }))
  description = "Containers keyed by container name. Secrets map an environment variable name to a Secrets Manager or SSM ARN."

  validation {
    condition     = length(var.containers) > 0
    error_message = "At least one container is required."
  }
}

variable "cpu" {
  type        = number
  description = "Task-level CPU units. 1024 is one vCPU."
  default     = 512
}

variable "memory" {
  type        = number
  description = "Task-level memory in mebibytes. Fargate accepts only certain pairings with cpu."
  default     = 1024
}

variable "desired_count" {
  type        = number
  description = "Tasks to run. Ignored after creation when autoscaling is configured."
  default     = 2
}

variable "launch_type" {
  type        = string
  description = "FARGATE or EC2. Null defers to the cluster's capacity provider strategy."
  default     = "FARGATE"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets for the task network interfaces. Private subnets, with a NAT gateway or VPC endpoints for image pulls."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups on the task network interfaces."
  default     = []
}

variable "assign_public_ip" {
  type        = bool
  description = "Give tasks a public IP. Needed in a public subnet with no NAT gateway, and best avoided otherwise."
  default     = false
}

variable "load_balancers" {
  type = map(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
  description = "Target groups to register tasks with, keyed by a stable name."
  default     = {}
}

variable "task_role_arn" {
  type        = string
  description = "Role the application code assumes. Null means the container calls no AWS API."
  default     = null
}

variable "execution_role_arn" {
  type        = string
  description = "Role ECS itself uses to pull images and read secrets. Required when containers name any secrets."
  default     = null
}

variable "log_retention_days" {
  type        = number
  description = "Days to keep container logs."
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "The retention period must be one of the values CloudWatch Logs accepts; seven years is 2557, not 2555."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key encrypting the log group."
  default     = null
}

variable "enable_execute_command" {
  type        = bool
  description = "Allow ECS Exec into a running task. Useful for debugging, and it is a shell into production."
  default     = false
}

variable "deployment" {
  type = object({
    minimum_healthy_percent = optional(number, 100)
    maximum_percent         = optional(number, 200)
    circuit_breaker         = optional(bool, true)
    rollback_on_failure     = optional(bool, true)
  })
  description = "Rolling deployment settings. The circuit breaker stops a broken deployment rather than replacing every task with it."
  default     = {}
}

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds before load balancer health checks count against a new task. Only valid with a load balancer."
  default     = null
}

variable "autoscaling" {
  type = object({
    min_capacity   = number
    max_capacity   = number
    cpu_target     = optional(number)
    memory_target  = optional(number)
    request_target = optional(number)
    resource_label = optional(string)
  })
  description = "Application autoscaling. Null keeps the task count fixed at desired_count."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource this module creates."
  default     = {}
}
