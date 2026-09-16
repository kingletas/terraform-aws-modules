# ecs-cluster

An ECS cluster with Container Insights and a log group recording every ECS Exec session.

## Usage

```hcl
module "cluster" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ecs-cluster?ref=v0.4.0"

  name        = "platform"
  kms_key_arn = module.kms.arn

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = [
    { capacity_provider = "FARGATE", base = 2, weight = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 4 },
  ]
}
```

## ECS Exec sessions are recorded

`execute_command_logging` defaults to `OVERRIDE`, which sends every exec session to a log group this module creates. ECS Exec is a shell inside a running production container; a session nobody recorded is a session nobody can review afterwards.

## Notes

- The capacity provider strategy above keeps two tasks on on-demand capacity and puts four in five of the rest on spot. `base` is the floor that never moves to spot.
- `container_insights` accepts `enhanced`, which adds per-task metrics at meaningfully higher cost.

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
| [aws_cloudwatch_log_group.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Cluster name. | `string` | n/a | yes |
| container\_insights | Container Insights level: enhanced, enabled or disabled. Enhanced adds per-task metrics and costs more. | `string` | `"enabled"` | no |
| capacity\_providers | Capacity providers available to the cluster. | `list(string)` | <pre>[<br/>  "FARGATE",<br/>  "FARGATE_SPOT"<br/>]</pre> | no |
| default\_capacity\_provider\_strategy | How tasks are placed when a service names no strategy of its own. | <pre>list(object({<br/>    capacity_provider = string<br/>    weight            = optional(number, 1)<br/>    base              = optional(number, 0)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "base": 1,<br/>    "capacity_provider": "FARGATE",<br/>    "weight": 1<br/>  }<br/>]</pre> | no |
| execute\_command\_logging | Where ECS Exec sessions are recorded: NONE, DEFAULT, OVERRIDE. A session that is not recorded is a shell nobody audited. | `string` | `"OVERRIDE"` | no |
| log\_retention\_days | Days to keep the cluster's exec log group. | `number` | `365` | no |
| kms\_key\_arn | KMS key encrypting ECS Exec sessions and the log group. | `string` | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the cluster. |
| arn | ARN of the cluster. |
| name | Name of the cluster. |
| exec\_log\_group\_name | Log group holding ECS Exec session records, or null when exec logging is not overridden. |
<!-- END_TF_DOCS -->
