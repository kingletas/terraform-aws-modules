locals {
  from_openapi = var.openapi_body != null

  # Each route's path without its outer slashes; the root is the empty string.
  route_paths = local.from_openapi ? {} : { for key, route in var.routes : key => trim(route.path, "/") }

  path_segments = { for path in distinct(values(local.route_paths)) : path => path == "" ? [] : split("/", path) }

  # Every prefix of every path becomes a resource, grouped by depth so each level can name its parent.
  resource_prefixes = distinct(flatten([
    for path, segments in local.path_segments : [
      for depth in range(1, length(segments) + 1) : join("/", slice(segments, 0, depth))
    ]
  ]))

  resource_levels = [
    for depth in range(1, 7) : {
      for prefix in local.resource_prefixes : prefix => {
        path_part = element(split("/", prefix), depth - 1)
        parent    = join("/", slice(split("/", prefix), 0, depth - 1))
      } if length(split("/", prefix)) == depth
    }
  ]

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_api_gateway_rest_api" "this" {
  name        = var.name
  description = var.description
  body        = var.openapi_body
  policy      = var.policy_json

  endpoint_configuration {
    types            = [var.endpoint_type]
    vpc_endpoint_ids = var.endpoint_type == "PRIVATE" ? var.vpc_endpoint_ids : null
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = local.from_openapi || length(var.routes) > 0
      error_message = "Give the API something to serve: an openapi_body or at least one route."
    }
  }
}

resource "aws_api_gateway_resource" "level_1" {
  for_each = local.resource_levels[0]

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level_2" {
  for_each = local.resource_levels[1]

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_1[each.value.parent].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level_3" {
  for_each = local.resource_levels[2]

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_2[each.value.parent].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level_4" {
  for_each = local.resource_levels[3]

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_3[each.value.parent].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level_5" {
  for_each = local.resource_levels[4]

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_4[each.value.parent].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level_6" {
  for_each = local.resource_levels[5]

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level_5[each.value.parent].id
  path_part   = each.value.path_part
}

moved {
  from = aws_api_gateway_resource.this
  to   = aws_api_gateway_resource.level_1
}

locals {
  resource_ids = merge(
    { "" = aws_api_gateway_rest_api.this.root_resource_id },
    { for prefix, resource in aws_api_gateway_resource.level_1 : prefix => resource.id },
    { for prefix, resource in aws_api_gateway_resource.level_2 : prefix => resource.id },
    { for prefix, resource in aws_api_gateway_resource.level_3 : prefix => resource.id },
    { for prefix, resource in aws_api_gateway_resource.level_4 : prefix => resource.id },
    { for prefix, resource in aws_api_gateway_resource.level_5 : prefix => resource.id },
    { for prefix, resource in aws_api_gateway_resource.level_6 : prefix => resource.id },
  )
}

resource "aws_api_gateway_authorizer" "this" {
  for_each = local.from_openapi ? {} : var.authorizers

  name                             = each.key
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  type                             = each.value.type
  provider_arns                    = each.value.type == "COGNITO_USER_POOLS" ? each.value.provider_arns : null
  identity_source                  = each.value.identity_source
  authorizer_uri                   = each.value.authorizer_uri
  authorizer_credentials           = each.value.authorizer_credentials
  authorizer_result_ttl_in_seconds = each.value.result_ttl_seconds
}

resource "aws_api_gateway_method" "this" {
  for_each = local.from_openapi ? {} : var.routes

  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = local.resource_ids[local.route_paths[each.key]]
  http_method      = each.value.method
  authorization    = each.value.authorization
  authorizer_id    = each.value.authorizer_key == null ? null : aws_api_gateway_authorizer.this[each.value.authorizer_key].id
  api_key_required = each.value.api_key_required

  request_parameters = each.value.request_parameters
}

resource "aws_api_gateway_integration" "this" {
  for_each = local.from_openapi ? {} : var.routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = local.resource_ids[local.route_paths[each.key]]
  http_method = aws_api_gateway_method.this[each.key].http_method

  type                    = each.value.integration_type
  integration_http_method = each.value.integration_type == "MOCK" ? null : each.value.integration_http_method
  uri                     = each.value.integration_type == "MOCK" ? null : (each.value.lambda_invoke_arn != null ? each.value.lambda_invoke_arn : each.value.integration_uri)
}

resource "aws_cloudwatch_log_group" "access" {
  name              = format("/aws/apigateway/%s/%s", var.name, var.stage_name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "account_logging_assume_role" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "account_logging" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  name_prefix        = format("%s-apigw-logs-", substr(var.name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.account_logging_assume_role[0].json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "account_logging" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  role       = aws_iam_role.account_logging[0].name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs", data.aws_partition.current.partition)
}

# One setting per account and region; destroying this leaves the role ARN set on the account.
resource "aws_api_gateway_account" "this" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.account_logging[0].arn

  depends_on = [aws_iam_role_policy_attachment.account_logging]
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Redeploy whenever the API's shape changes, which nothing else detects.
  triggers = {
    redeployment = sha1(jsonencode([
      var.openapi_body,
      var.routes,
      var.authorizers,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.this,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name

  xray_tracing_enabled = var.xray_tracing_enabled

  depends_on = [aws_api_gateway_account.this]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.resourcePath"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  tags = local.tags
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = var.metrics_enabled
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }
}
