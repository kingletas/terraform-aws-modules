module "api" {
  source = "../../modules/api-gateway-rest"

  name        = local.prefix
  description = format("%s API", var.name)
  stage_name  = var.stage_name

  routes = {
    for name, fn in local.http_functions : name => {
      path              = fn.http_path
      method            = fn.http_method
      lambda_invoke_arn = module.functions[name].invoke_arn
      authorization     = local.route_authorization
    }
  }

  throttling_rate_limit  = var.throttling_rate_limit
  throttling_burst_limit = var.throttling_rate_limit * 2

  kms_key_arn = module.kms.arn

  # Access logging needs the account-level API Gateway logging role.
  manage_account_cloudwatch_role = var.manage_api_gateway_account_role

  tags = local.tags
}

# The API needs each function's invoke ARN for its routes, and each function
# needs the API's ARN for its invoke permission. Declaring both inside the
# function module is a cycle Terraform cannot break, so the permission is a
# separate resource here, where it depends on both and neither depends on it.
resource "aws_lambda_permission" "api" {
  for_each = local.http_functions

  statement_id  = "AllowInvokeFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.functions[each.key].name
  principal     = "apigateway.amazonaws.com"

  # Scoped to this API. Without a source_arn, any API Gateway in any account
  # could invoke the function.
  source_arn = format("%s/*/*", module.api.arn)
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
      # A message here has failed three times. Nothing else will retry it, and
      # nothing else will tell you it exists.
      "${local.prefix}-dead-letters" = {
        description         = "Messages have landed in the dead letter queue"
        metric_name         = "ApproximateNumberOfMessagesVisible"
        namespace           = "AWS/SQS"
        statistic           = "Maximum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        evaluation_periods  = 1
        treat_missing_data  = "notBreaching"
        dimensions          = { QueueName = format("%s-work-dlq", local.prefix) }
      }

      # Age, not depth. A deep queue that is draining is fine; a shallow one
      # whose oldest message keeps getting older is not.
      "${local.prefix}-queue-age" = {
        description         = "The oldest unprocessed message is over five minutes old"
        metric_name         = "ApproximateAgeOfOldestMessage"
        namespace           = "AWS/SQS"
        statistic           = "Maximum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 300
        evaluation_periods  = 2
        treat_missing_data  = "notBreaching"
        dimensions          = { QueueName = module.work_queue.name }
      }

      "${local.prefix}-api-5xx" = {
        description         = "The API is returning server errors"
        metric_name         = "5XXError"
        namespace           = "AWS/ApiGateway"
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 5
        evaluation_periods  = 2
        treat_missing_data  = "notBreaching"
        dimensions          = { ApiName = local.prefix, Stage = var.stage_name }
      }

      # DynamoDB throttling is invisible in application logs unless the code
      # looks for it, and it presents as latency rather than as an error.
      "${local.prefix}-table-throttled" = {
        description         = "DynamoDB is throttling reads or writes"
        metric_name         = "ThrottledRequests"
        namespace           = "AWS/DynamoDB"
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 0
        evaluation_periods  = 2
        treat_missing_data  = "notBreaching"
        dimensions          = { TableName = module.orders.name }
      }
    },

    {
      for name, fn in var.functions : "${local.prefix}-${name}-errors" => {
        description         = "The ${name} function is failing"
        metric_name         = "Errors"
        namespace           = "AWS/Lambda"
        statistic           = "Sum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 5
        evaluation_periods  = 2
        treat_missing_data  = "notBreaching"
        dimensions          = { FunctionName = module.functions[name].name }
      }
    }
  )

  tags = local.tags
}
