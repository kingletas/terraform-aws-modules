locals {
  flow_logs_enabled = var.flow_log_retention_days > 0
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  name              = format("/aws/vpc/%s/flow-logs", var.name)
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.flow_log_kms_key_arn

  tags = local.tags
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  count = local.flow_logs_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.flow_logs[0].arn,
      format("%s:*", aws_cloudwatch_log_group.flow_logs[0].arn),
    ]
  }
}

resource "aws_iam_role" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  name_prefix        = format("%s-flow-logs-", substr(var.name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role[0].json

  tags = local.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = local.flow_logs_enabled ? 1 : 0

  name_prefix = "write-flow-logs-"
  role        = aws_iam_role.flow_logs[0].id
  policy      = data.aws_iam_policy_document.flow_logs[0].json
}

resource "aws_flow_log" "this" {
  count = local.flow_logs_enabled ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  max_aggregation_interval = 60

  tags = local.tags
}
