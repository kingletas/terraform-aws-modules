locals {
  prefix = format("%s-%s", var.name, var.environment)

  http_functions = { for name, fn in var.functions : name => fn if fn.http_path != null }

  tags = {
    Environment = var.environment
    Application = var.name
    ManagedBy   = "terraform"
  }
}

module "kms" {
  source = "../../modules/kms-key"

  name        = local.prefix
  description = "Serverless API data at rest"

  service_principals = [format("logs.%s.amazonaws.com", var.region)]

  tags = local.tags
}

# --- state ---

module "orders" {
  source = "../../modules/dynamodb-table"

  name      = format("%s-orders", local.prefix)
  hash_key  = "order_id"
  range_key = "created_at"

  attributes = [
    { name = "order_id", type = "S" },
    { name = "created_at", type = "N" },
    { name = "customer_id", type = "S" },
    { name = "status", type = "S" },
  ]

  global_secondary_indexes = {
    by_customer = {
      hash_key  = "customer_id"
      range_key = "created_at"
    }

    by_status = {
      hash_key        = "status"
      range_key       = "created_at"
      projection_type = "KEYS_ONLY"
    }
  }

  kms_key_arn   = module.kms.arn
  ttl_attribute = "expires_at"

  tags = local.tags
}

# --- work queue ---

# The API accepts an order and returns. Processing happens behind the queue, so
# a slow downstream call never becomes a slow response to the caller.
module "work_queue" {
  source = "../../modules/sqs-queue"

  name       = format("%s-work", local.prefix)
  kms_key_id = module.kms.key_id

  # Six times the consumer's timeout, which is what AWS asks for. Below that
  # the message reappears while the first invocation is still running.
  visibility_timeout_seconds = 720

  dead_letter_queue = {
    max_receive_count = 3
  }

  tags = local.tags
}

# --- roles ---

module "function_role" {
  source = "../../modules/iam-role"

  name             = format("%s-function", local.prefix)
  description      = "Lambda functions behind the orders API"
  trusted_services = ["lambda.amazonaws.com"]

  managed_policy_arns = {
    lambda_logs = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    xray        = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  }

  inline_policies = {
    orders = data.aws_iam_policy_document.function.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "function" {
  statement {
    sid    = "ReadWriteOrders"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]

    # The table and its indexes. An index has its own ARN, and a Query against
    # one is denied by a policy that names only the table.
    resources = [
      module.orders.arn,
      format("%s/index/*", module.orders.arn),
    ]
  }

  statement {
    sid    = "UseTheQueue"
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]

    resources = [module.work_queue.arn, module.work_queue.dead_letter_queue_arn]
  }

  statement {
    sid       = "UseTheKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [module.kms.arn]
  }
}

# --- functions ---

module "functions" {
  source   = "../../modules/lambda-function"
  for_each = var.functions

  name     = format("%s-%s", local.prefix, each.key)
  role_arn = module.function_role.arn

  s3_bucket = var.lambda_bucket
  s3_key    = each.value.s3_key

  handler = each.value.handler
  runtime = var.lambda_runtime

  memory_size = each.value.memory_size
  timeout     = each.value.timeout
  kms_key_arn = module.kms.arn

  environment_variables = merge(each.value.environment, {
    ORDERS_TABLE = module.orders.name
    WORK_QUEUE   = module.work_queue.id
  })

  # An asynchronous invocation that exhausts its retries goes here rather than
  # disappearing.
  dead_letter_target_arn = module.work_queue.dead_letter_queue_arn

  event_source_mappings = each.value.consumes_queue ? {
    work = {
      event_source_arn = module.work_queue.arn
      batch_size       = 10

      # Without this, one bad message in a batch fails the whole batch and every
      # message in it is retried, including the nine that succeeded.
      function_response_types = ["ReportBatchItemFailures"]
    }
  } : {}

  # The invoke permission is NOT set here. See the cycle note in api.tf.

  tags = merge(local.tags, { Function = each.key })
}
