# mwaa-environment

A Managed Workflows for Apache Airflow environment, with a private web server and per-component log levels.

## Usage

```hcl
module "airflow" {
  source = "github.com/kingletas/terraform-aws-modules//modules/mwaa-environment?ref=v0.1.0"

  name              = "warehouse"
  airflow_version   = "2.10.3"
  environment_class = "mw1.small"

  source_bucket_arn  = module.dags.arn
  execution_role_arn = module.airflow_role.arn
  kms_key_arn        = module.kms.arn

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.airflow_sg.id]

  min_workers = 1
  max_workers = 10
  schedulers  = 2
}
```

## Three requirements that fail late

MWAA takes **20 to 30 minutes** to create, and these fail near the end of it:

1. **Exactly two subnets**, in different availability zones. Not one, not three. The module validates this at plan time instead.
2. **The security group must allow all traffic from itself.** MWAA's scheduler, workers and web server reach each other through it, and the failure message does not mention security groups.
3. **The DAG bucket must have versioning enabled**, or MWAA refuses outright.

## A changed file at the same key does nothing

MWAA reads `requirements.txt` and `plugins.zip` by **object version**. Overwrite the file at the same key and the environment keeps running the old one — no error, no restart, no sign anything was meant to change.

Pass `requirements_s3_object_version` and `plugins_s3_object_version`, or version the key itself.

## Notes

- **An Airflow version upgrade replaces the environment.** It is not an in-place change, and it means downtime and a re-created scheduler.
- `PRIVATE_ONLY` keeps the UI inside the VPC, which needs a VPN or a bastion to reach. `PUBLIC_ONLY` puts it on the internet behind IAM authentication.
- `min_workers` are billed whether a DAG runs or not. There is no scale to zero — an idle `mw1.small` environment is still several hundred dollars a month.
- **The execution role needs the Celery SQS queue**, which lives in *AWS's* account: `arn:aws:sqs:<region>:*:airflow-celery-*`. The wildcard account is correct and looks wrong in a review.
- `schedulers = 2` gives scheduler high availability and is what Airflow 2 supports.
- Log levels default to `WARNING` for the noisy components and `INFO` for tasks, because the DAG processor at `INFO` produces a great deal of CloudWatch ingestion for very little.

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
| [aws_mwaa_environment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/mwaa_environment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Environment name. | `string` | n/a | yes |
| airflow\_version | Airflow version. Upgrading is a replacement of the environment, not an in-place change. | `string` | `"2.10.3"` | no |
| environment\_class | Size of the scheduler and web server: mw1.micro, mw1.small, mw1.medium or mw1.large. | `string` | `"mw1.small"` | no |
| source\_bucket\_arn | Bucket holding the DAGs. Versioning must be enabled on it or MWAA refuses to create the environment. | `string` | n/a | yes |
| dag\_s3\_path | Prefix inside the bucket holding the DAG files. | `string` | `"dags/"` | no |
| requirements\_s3\_path | Path to requirements.txt. Null installs no extra packages. | `string` | `null` | no |
| requirements\_s3\_object\_version | Object version of requirements.txt. MWAA does not notice a changed file at the same key without this. | `string` | `null` | no |
| plugins\_s3\_path | Path to plugins.zip. Null installs no plugins. | `string` | `null` | no |
| plugins\_s3\_object\_version | Object version of plugins.zip, for the same reason as requirements. | `string` | `null` | no |
| startup\_script\_s3\_path | Path to a startup shell script run on every worker before Airflow starts. | `string` | `null` | no |
| execution\_role\_arn | Role the environment and its tasks run as. It needs the bucket, the logs, SQS and the KMS key. | `string` | n/a | yes |
| subnet\_ids | Private subnets, exactly two, in different availability zones. MWAA accepts no other count. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups for the environment. They must allow all traffic from themselves, which is how MWAA's components reach each other. | `list(string)` | n/a | yes |
| webserver\_access\_mode | PRIVATE\_ONLY keeps the Airflow UI inside the VPC. PUBLIC\_ONLY puts it on the internet behind IAM. | `string` | `"PRIVATE_ONLY"` | no |
| endpoint\_management | SERVICE lets MWAA create its own VPC endpoints. CUSTOMER means you create them, which is needed in a shared VPC. | `string` | `"SERVICE"` | no |
| max\_workers | Ceiling for worker autoscaling. | `number` | `10` | no |
| min\_workers | Workers always running. These are billed whether a DAG is scheduled or not. | `number` | `1` | no |
| schedulers | Scheduler count. Two or more needs Airflow 2 and gives scheduler high availability. | `number` | `2` | no |
| kms\_key\_arn | KMS key encrypting the environment's data and logs. Null uses the AWS-managed key. | `string` | `null` | no |
| airflow\_configuration\_options | Airflow configuration overrides, using dotted names such as core.default\_task\_retries. | `map(string)` | `{}` | no |
| logging | Log configuration keyed by dag\_processing, scheduler, task, webserver or worker. Task logs are the ones you actually read. | <pre>map(object({<br/>    enabled   = optional(bool, true)<br/>    log_level = optional(string, "INFO")<br/>  }))</pre> | <pre>{<br/>  "dag_processing": {<br/>    "log_level": "WARNING"<br/>  },<br/>  "scheduler": {<br/>    "log_level": "WARNING"<br/>  },<br/>  "task": {<br/>    "log_level": "INFO"<br/>  },<br/>  "webserver": {<br/>    "log_level": "WARNING"<br/>  },<br/>  "worker": {<br/>    "log_level": "INFO"<br/>  }<br/>}</pre> | no |
| weekly\_maintenance\_window\_start | Weekly maintenance window in UTC, as DAY:HH:MM. | `string` | `"SUN:05:00"` | no |
| tags | Tags applied to the environment. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the environment. |
| name | Name of the environment. |
| webserver\_url | Airflow UI. Reachable only from inside the VPC when access mode is PRIVATE\_ONLY. |
| status | Environment status. Creation takes 20 to 30 minutes. |
| service\_role\_arn | Service-linked role MWAA created for itself. |
| logging\_group\_arns | CloudWatch log groups MWAA writes to, keyed by log type. |
<!-- END_TF_DOCS -->
