# --- what the pipeline is allowed to do ---

module "pipeline_role" {
  source = "../../modules/iam-role"

  name             = format("%s-pipeline", local.prefix)
  description      = "Extraction and transform jobs"
  trusted_services = ["states.amazonaws.com", "lambda.amazonaws.com"]

  managed_policy_arns = {
    lambda_logs = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  }

  inline_policies = {
    pipeline = data.aws_iam_policy_document.pipeline.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    sid       = "WriteRaw"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [module.raw.arn, format("%s/*", module.raw.arn)]
  }

  statement {
    sid       = "ReadWriteCurated"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [module.curated.arn, format("%s/*", module.curated.arn)]
  }

  statement {
    sid       = "ReadSourceCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [for name, secret in module.source_credentials : secret.arn]
  }

  statement {
    sid    = "RecordRuns"
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]

    resources = [module.run_ledger.arn, format("%s/index/*", module.run_ledger.arn)]
  }

  statement {
    sid       = "UseTheKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [module.kms.arn]
  }

  # Step Functions sets up log delivery through vended-log APIs that take no resource ARN.
  statement {
    sid    = "DeliverExecutionLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]

    resources = ["*"]
  }

  # The step-function module traces with X-Ray by default, and these actions take no resource ARN.
  statement {
    sid    = "WriteTraces"
    effect = "Allow"

    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]

    resources = ["*"]
  }
}

# --- orchestration ---

# What each extraction receives: where the source is and which secret holds its credentials. No secret value is in it.
locals {
  extract_input = {
    sources = [
      for name, source in var.sources : {
        name                   = name
        engine                 = source.engine
        server_name            = source.server_name
        port                   = source.port
        database               = source.database
        credentials_secret_arn = module.source_credentials[name].arn
      }
    ]
  }
}

module "extract" {
  source = "../../modules/step-function"

  name     = format("%s-extract", local.prefix)
  role_arn = module.pipeline_role.arn

  # STANDARD, not EXPRESS. A nightly load runs for an hour, which EXPRESS caps
  # out of at five minutes, and the execution history is the audit trail.
  type = "STANDARD"

  # Full logging, because "did last night finish" is a question asked in the
  # morning about a run nobody watched.
  log_level              = "ALL"
  include_execution_data = false

  kms_key_arn = module.kms.arn

  definition_json = jsonencode({
    Comment = "Extract every configured source into the raw zone"
    StartAt = "ForEachSource"
    States = {
      ForEachSource = {
        Type      = "Map"
        ItemsPath = "$.sources"

        # Sources are extracted a few at a time. Unbounded parallelism opens
        # every source connection at once, which is how a pipeline takes down
        # the production database it is reading from.
        MaxConcurrency = 3

        ItemProcessor = {
          ProcessorConfig = { Mode = "INLINE" }
          StartAt         = "ExtractOne"
          States = {
            ExtractOne = {
              Type     = "Task"
              Resource = "arn:aws:states:::aws-sdk:s3:putObject"
              End      = true

              Retry = [{
                ErrorEquals     = ["States.TaskFailed"]
                IntervalSeconds = 30
                MaxAttempts     = 3
                BackoffRate     = 2
              }]
            }
          }
        }

        End = true
      }
    }
  })

  tags = local.tags
}

module "transform" {
  source = "../../modules/step-function"

  name        = format("%s-transform", local.prefix)
  role_arn    = module.pipeline_role.arn
  type        = "STANDARD"
  log_level   = "ALL"
  kms_key_arn = module.kms.arn

  definition_json = jsonencode({
    Comment = "Build curated datasets from the raw zone"
    StartAt = "Transform"
    States = {
      Transform = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:s3:listObjectsV2"
        End      = true

        Retry = [{
          ErrorEquals     = ["States.TaskFailed"]
          IntervalSeconds = 60
          MaxAttempts     = 2
          BackoffRate     = 2
        }]
      }
    }
  })

  tags = local.tags
}

# --- schedules ---

module "scheduler_role" {
  source = "../../modules/iam-role"

  name             = format("%s-scheduler", local.prefix)
  description      = "EventBridge starting pipeline executions"
  trusted_services = ["events.amazonaws.com"]

  inline_policies = {
    start_executions = data.aws_iam_policy_document.scheduler.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [module.extract.arn, module.transform.arn]
  }
}

# Failed deliveries land here rather than disappearing. A schedule that
# silently did not fire is the worst failure a batch pipeline has.
module "missed_runs" {
  source = "../../modules/sqs-queue"

  name              = format("%s-missed-runs", local.prefix)
  kms_key_id        = module.kms.key_id
  dead_letter_queue = { enabled = false }

  attach_policy = true
  policy_json   = data.aws_iam_policy_document.missed_runs.json

  tags = local.tags
}

locals {
  schedule_names = {
    extract   = format("%s-extract", local.prefix)
    transform = format("%s-transform", local.prefix)
  }

  schedule_rule_arns = [
    for rule, name in local.schedule_names : format("arn:%s:events:%s:%s:rule/%s",
      data.aws_partition.current.partition, var.region,
      data.aws_caller_identity.current.account_id, name
    )
  ]
}

# EventBridge can only dead-letter into a queue whose policy lets the failing rule send to it.
data "aws_iam_policy_document" "missed_runs" {
  statement {
    sid       = "AllowScheduleDeadLetters"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.missed_runs.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = local.schedule_rule_arns
    }
  }
}

module "extract_schedule" {
  source = "../../modules/eventbridge-rule"

  name                = local.schedule_names.extract
  description         = "Nightly extraction"
  schedule_expression = var.extract_schedule

  targets = {
    extract = {
      arn             = module.extract.arn
      role_arn        = module.scheduler_role.arn
      dead_letter_arn = module.missed_runs.arn
      input           = jsonencode(local.extract_input)
    }
  }

  tags = local.tags
}

module "transform_schedule" {
  source = "../../modules/eventbridge-rule"

  name                = local.schedule_names.transform
  description         = "Nightly transform, after extraction has had time to finish"
  schedule_expression = var.transform_schedule

  targets = {
    transform = {
      arn             = module.transform.arn
      role_arn        = module.scheduler_role.arn
      dead_letter_arn = module.missed_runs.arn
    }
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

  alarms = {
    "${local.prefix}-extract-failed" = {
      description         = "The nightly extraction failed"
      metric_name         = "ExecutionsFailed"
      namespace           = "AWS/States"
      statistic           = "Sum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      evaluation_periods  = 1
      treat_missing_data  = "notBreaching"
      dimensions          = { StateMachineArn = module.extract.arn }
    }

    "${local.prefix}-transform-failed" = {
      description         = "The nightly transform failed"
      metric_name         = "ExecutionsFailed"
      namespace           = "AWS/States"
      statistic           = "Sum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      evaluation_periods  = 1
      treat_missing_data  = "notBreaching"
      dimensions          = { StateMachineArn = module.transform.arn }
    }

    # A pipeline that did not run looks exactly like a pipeline with nothing to
    # do. treat_missing_data = breaching is what tells the two apart.
    "${local.prefix}-extract-did-not-run" = {
      description         = "No extraction started in the last 26 hours"
      metric_name         = "ExecutionsStarted"
      namespace           = "AWS/States"
      statistic           = "Sum"
      comparison_operator = "LessThanThreshold"
      threshold           = 1
      evaluation_periods  = 1
      period              = 93600
      treat_missing_data  = "breaching"
      dimensions          = { StateMachineArn = module.extract.arn }
    }

    "${local.prefix}-missed-schedule" = {
      description         = "EventBridge could not deliver a scheduled run"
      metric_name         = "ApproximateNumberOfMessagesVisible"
      namespace           = "AWS/SQS"
      statistic           = "Maximum"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 0
      evaluation_periods  = 1
      treat_missing_data  = "notBreaching"
      dimensions          = { QueueName = module.missed_runs.name }
    }
  }

  tags = local.tags
}
