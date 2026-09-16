# --- what Airflow is allowed to do ---

module "airflow_role" {
  source = "../../modules/iam-role"

  name        = format("%s-airflow", local.prefix)
  description = "MWAA environment and the tasks it runs"

  # Both principals. MWAA assumes this role as the service, and the tasks
  # running inside the environment assume it too.
  trusted_services = ["airflow.amazonaws.com", "airflow-env.amazonaws.com"]

  inline_policies = {
    orchestration = data.aws_iam_policy_document.airflow.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "airflow" {
  statement {
    sid       = "ReadDags"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"]
    resources = [module.dags.arn, format("%s/*", module.dags.arn)]
  }

  # MWAA writes to log groups it creates itself, whose names it decides.
  statement {
    sid    = "WriteItsOwnLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogRecord",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults",
      "logs:DescribeLogGroups",
    ]

    resources = [format("arn:%s:logs:%s:%s:log-group:airflow-%s-*",
      data.aws_partition.current.partition, var.region,
      data.aws_caller_identity.current.account_id, local.prefix
    )]
  }

  statement {
    sid       = "PublishMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  # MWAA's Celery executor runs on an SQS queue AWS owns in its own account,
  # which is why this cannot be scoped to a queue ARN of yours.
  statement {
    sid    = "CeleryQueue"
    effect = "Allow"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
    ]

    resources = [format("arn:%s:sqs:%s:*:airflow-celery-*", data.aws_partition.current.partition, var.region)]
  }

  statement {
    sid    = "UseTheKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
    ]

    resources = [module.kms.arn]
  }

  # Airflow starts and watches the replication tasks rather than DMS running
  # them on its own schedule.
  statement {
    sid    = "DriveReplication"
    effect = "Allow"

    actions = [
      "dms:StartReplicationTask",
      "dms:StopReplicationTask",
      "dms:DescribeReplicationTasks",
      "dms:DescribeTableStatistics",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "QueryTheWarehouse"
    effect = "Allow"

    actions = [
      "redshift-data:ExecuteStatement",
      "redshift-data:DescribeStatement",
      "redshift-data:GetStatementResult",
    ]

    resources = [module.warehouse.arn]
  }

  # GetClusterCredentials mints a short-lived database login. Unscoped it can
  # mint one for any cluster in the account, as any database user.
  statement {
    sid     = "MintWarehouseLogin"
    effect  = "Allow"
    actions = ["redshift:GetClusterCredentials"]

    resources = [
      format("arn:%s:redshift:%s:%s:dbuser:%s/%s",
        data.aws_partition.current.partition, var.region,
        data.aws_caller_identity.current.account_id,
        module.warehouse.id, module.warehouse.master_username
      ),
      format("arn:%s:redshift:%s:%s:dbname:%s/%s",
        data.aws_partition.current.partition, var.region,
        data.aws_caller_identity.current.account_id,
        module.warehouse.id, module.warehouse.database_name
      ),
    ]
  }

  statement {
    sid       = "ReadWarehouseCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.warehouse_secret.arn]
  }
}

locals {
  airflow_micro = var.airflow_environment_class == "mw1.micro"
}

module "airflow" {
  source = "../../modules/mwaa-environment"

  name              = local.prefix
  airflow_version   = var.airflow_version
  environment_class = var.airflow_environment_class

  source_bucket_arn  = module.dags.arn
  dag_s3_path        = "dags/"
  execution_role_arn = module.airflow_role.arn
  kms_key_arn        = module.kms.arn

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.airflow_sg.id]

  # The UI stays inside the VPC. Reaching it means a VPN or a bastion, which
  # is the trade against putting an Airflow UI on the internet.
  webserver_access_mode = "PRIVATE_ONLY"

  # mw1.micro runs exactly one scheduler and one worker.
  min_workers = 1
  max_workers = local.airflow_micro ? 1 : var.airflow_max_workers
  schedulers  = local.airflow_micro ? 1 : 2

  airflow_configuration_options = {
    "core.default_task_retries"       = "2"
    "core.dag_file_processor_timeout" = "150"
    "webserver.default_ui_timezone"   = "UTC"
  }

  tags = local.tags
}

# --- operations ---

module "alerts" {
  source = "../../modules/sns-topic"

  name       = format("%s-alerts", local.prefix)
  kms_key_id = module.kms.key_id

  subscriptions = var.alert_email == null ? {} : {
    oncall = {
      protocol = "email"
      endpoint = var.alert_email
    }
  }

  tags = local.tags
}

module "alarms" {
  source = "../../modules/cloudwatch-alarm"

  default_alarm_actions = [module.alerts.arn]
  default_ok_actions    = [module.alerts.arn]

  alarms = merge(
    {
      # A scheduler that has stopped heartbeating means no DAG is being
      # scheduled at all, and every run simply does not happen.
      "${local.prefix}-scheduler-stopped" = {
        description         = "The Airflow scheduler has stopped heartbeating"
        metric_name         = "SchedulerHeartbeat"
        namespace           = "AmazonMWAA"
        statistic           = "Sum"
        comparison_operator = "LessThanThreshold"
        threshold           = 1
        evaluation_periods  = 2
        treat_missing_data  = "breaching"
        dimensions          = { Function = "Scheduler", Environment = module.airflow.name }
      }

      # Tasks queued with nothing picking them up.
      "${local.prefix}-tasks-queued" = {
        description         = "Airflow tasks have been queued without running"
        metric_name         = "QueuedTasks"
        namespace           = "AmazonMWAA"
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 10
        evaluation_periods  = 3
        treat_missing_data  = "notBreaching"
        dimensions          = { Function = "Executor", Environment = module.airflow.name }
      }

      "${local.prefix}-redshift-disk" = {
        description         = "The warehouse is above 85% disk"
        metric_name         = "PercentageDiskSpaceUsed"
        namespace           = "AWS/Redshift"
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 85
        evaluation_periods  = 3
        dimensions          = { ClusterIdentifier = module.warehouse.id }
      }
    },

    # Replication lag is the number that says whether the warehouse is telling
    # the truth about the source, and it is invisible until somebody looks.
    {
      for name, source in var.sources : "${local.prefix}-${name}-cdc-lag" => {
        description         = "Change capture from ${name} is more than an hour behind"
        metric_name         = "CDCLatencyTarget"
        namespace           = "AWS/DMS"
        statistic           = "Average"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 3600
        evaluation_periods  = 3
        treat_missing_data  = "notBreaching"

        dimensions = {
          ReplicationInstanceIdentifier = module.replication.replication_instance_id
          ReplicationTaskIdentifier     = format("%s-%s", local.prefix, name)
        }
      }
    }
  )

  tags = local.tags
}
