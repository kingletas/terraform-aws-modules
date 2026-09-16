# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "random" {}

run "plans_with_real_values" {
  command = plan

  variables {
    sources = { erp = { engine = "sqlserver", server_name = "erp.internal", port = 1433, database = "erp", username = "loader" } }
  }

  assert {
    condition = toset(one([for statement in data.aws_iam_policy_document.pipeline.statement : statement.actions if statement.sid == "DeliverExecutionLogs"])) == toset([
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ])
    error_message = "The pipeline role must carry every log delivery action a state machine logging at ALL needs."
  }

  assert {
    condition     = one([for statement in data.aws_iam_policy_document.pipeline.statement : statement.resources if statement.sid == "DeliverExecutionLogs"]) == toset(["*"])
    error_message = "Log delivery actions take no resource ARN, so they must be granted on *."
  }

  assert {
    condition     = contains(flatten([for statement in data.aws_iam_policy_document.pipeline.statement : statement.actions]), "xray:PutTraceSegments")
    error_message = "The state machines trace with X-Ray, so the pipeline role must be able to write trace segments."
  }

  assert {
    condition     = toset(flatten([for principal in data.aws_iam_policy_document.missed_runs.statement[0].principals : principal.identifiers])) == toset(["events.amazonaws.com"])
    error_message = "The missed-runs queue policy must let EventBridge send to it."
  }

  assert {
    condition = toset(one([for condition in data.aws_iam_policy_document.missed_runs.statement[0].condition : condition.values if condition.variable == "aws:SourceArn"])) == toset([
      "arn:aws:events:us-east-1:123456789012:rule/warehouse-production-extract",
      "arn:aws:events:us-east-1:123456789012:rule/warehouse-production-transform",
    ])
    error_message = "EventBridge may dead-letter into the queue only from this pipeline's two schedule rules, named by aws:SourceArn."
  }

  assert {
    condition = [for source in local.extract_input.sources : [source.name, source.engine, source.server_name, tostring(source.port), source.database]] == [
      ["erp", "sqlserver", "erp.internal", "1433", "erp"],
    ]
    error_message = "Each extraction must receive its source's engine, server name, port and database."
  }
}
