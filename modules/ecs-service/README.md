# ecs-service

A task definition and the service that runs it, with a deployment circuit breaker and optional autoscaling.

## Usage

```hcl
module "api" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ecs-service?ref=v0.1.0"

  name        = "platform-api"
  cluster_arn = module.cluster.arn

  cpu    = 1024
  memory = 2048

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.api_sg.id]

  task_role_arn      = module.api_task_role.arn
  execution_role_arn = module.api_execution_role.arn

  containers = {
    api = {
      image = "${module.api_image.repository_url}:v1.4.2"
      ports = [{ container_port = 8080 }]

      environment = { LOG_LEVEL = "info" }
      secrets     = { DATABASE_URL = module.db_secret.arn }
    }
  }

  load_balancers = {
    public = {
      target_group_arn = module.alb.target_group_arns["app"]
      container_name   = "api"
      container_port   = 8080
    }
  }

  autoscaling = {
    min_capacity = 2
    max_capacity = 20
    cpu_target   = 60
  }
}
```

## Two roles, and mixing them up is the usual first failure

- **`execution_role_arn`** is what ECS itself uses, before your code runs, to pull the image and read the secrets. A container naming any `secrets` needs one, and the module refuses the plan without it.
- **`task_role_arn`** is what your application code assumes at runtime.

A missing execution role shows up as a task that never starts, with the reason buried in the stopped-task detail rather than in the logs.

## Notes

- `secrets` maps an environment variable name to a Secrets Manager or SSM ARN. The value is fetched at start and never appears in the task definition.
- The **deployment circuit breaker** stops a failing rollout and rolls back, instead of patiently replacing every healthy task with a broken one.
- `readonly_root_filesystem` defaults to true. An application that writes to disk needs a volume or an explicit false.
- `desired_count` is in `ignore_changes`, so autoscaling owns it once the service is running.

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
| [aws_appautoscaling_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Service name, also used for the task definition family and the log group. | `string` | n/a | yes |
| cluster\_arn | Cluster to run in. | `string` | n/a | yes |
| containers | Containers keyed by container name. Secrets map an environment variable name to a Secrets Manager or SSM ARN. | <pre>map(object({<br/>    image      = string<br/>    cpu        = optional(number)<br/>    memory     = optional(number)<br/>    essential  = optional(bool, true)<br/>    command    = optional(list(string))<br/>    entrypoint = optional(list(string))<br/><br/>    ports = optional(list(object({<br/>      container_port = number<br/>      protocol       = optional(string, "tcp")<br/>      name           = optional(string)<br/>    })), [])<br/><br/>    environment = optional(map(string), {})<br/>    secrets     = optional(map(string), {})<br/><br/>    health_check_command  = optional(list(string))<br/>    health_check_interval = optional(number, 30)<br/>    health_check_retries  = optional(number, 3)<br/><br/>    readonly_root_filesystem = optional(bool, true)<br/>    user                     = optional(string)<br/>    depends_on_containers    = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| cpu | Task-level CPU units. 1024 is one vCPU. | `number` | `512` | no |
| memory | Task-level memory in mebibytes. Fargate accepts only certain pairings with cpu. | `number` | `1024` | no |
| desired\_count | Tasks to run. Ignored after creation when autoscaling is configured. | `number` | `2` | no |
| launch\_type | FARGATE or EC2. Null defers to the cluster's capacity provider strategy. | `string` | `"FARGATE"` | no |
| subnet\_ids | Subnets for the task network interfaces. Private subnets, with a NAT gateway or VPC endpoints for image pulls. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups on the task network interfaces. | `list(string)` | `[]` | no |
| assign\_public\_ip | Give tasks a public IP. Needed in a public subnet with no NAT gateway, and best avoided otherwise. | `bool` | `false` | no |
| load\_balancers | Target groups to register tasks with, keyed by a stable name. | <pre>map(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | `{}` | no |
| task\_role\_arn | Role the application code assumes. Null means the container calls no AWS API. | `string` | `null` | no |
| execution\_role\_arn | Role ECS itself uses to pull images and read secrets. Required when containers name any secrets. | `string` | `null` | no |
| log\_retention\_days | Days to keep container logs. | `number` | `365` | no |
| kms\_key\_arn | KMS key encrypting the log group. | `string` | `null` | no |
| enable\_execute\_command | Allow ECS Exec into a running task. Useful for debugging, and it is a shell into production. | `bool` | `false` | no |
| deployment | Rolling deployment settings. The circuit breaker stops a broken deployment rather than replacing every task with it. | <pre>object({<br/>    minimum_healthy_percent = optional(number, 100)<br/>    maximum_percent         = optional(number, 200)<br/>    circuit_breaker         = optional(bool, true)<br/>    rollback_on_failure     = optional(bool, true)<br/>  })</pre> | `{}` | no |
| health\_check\_grace\_period\_seconds | Seconds before load balancer health checks count against a new task. Only valid with a load balancer. | `number` | `null` | no |
| autoscaling | Application autoscaling. Null keeps the task count fixed at desired\_count. | <pre>object({<br/>    min_capacity   = number<br/>    max_capacity   = number<br/>    cpu_target     = optional(number)<br/>    memory_target  = optional(number)<br/>    request_target = optional(number)<br/>    resource_label = optional(string)<br/>  })</pre> | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the service. |
| name | Name of the service. |
| task\_definition\_arn | ARN of the task definition revision the service is running. |
| task\_definition\_family | Task definition family name. |
| task\_definition\_revision | Revision number of the task definition. |
| log\_group\_name | CloudWatch log group holding container logs. |
| autoscaling\_target\_resource\_id | Application autoscaling resource ID, or null when autoscaling is off. |
<!-- END_TF_DOCS -->
