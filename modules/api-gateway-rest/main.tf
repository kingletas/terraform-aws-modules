locals {
  from_openapi = var.openapi_body != null

  path_list = distinct([for key, route in var.routes : route.path])

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

resource "aws_api_gateway_resource" "this" {
  for_each = toset(local.path_list)

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = trimprefix(each.value, "/")
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
  resource_id      = aws_api_gateway_resource.this[each.value.path].id
  http_method      = each.value.method
  authorization    = each.value.authorization
  authorizer_id    = each.value.authorizer_key == null ? null : aws_api_gateway_authorizer.this[each.value.authorizer_key].id
  api_key_required = each.value.api_key_required

  request_parameters = each.value.request_parameters
}

resource "aws_api_gateway_integration" "this" {
  for_each = local.from_openapi ? {} : var.routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.this[each.value.path].id
  http_method = aws_api_gateway_method.this[each.key].http_method

  type                    = each.value.integration_type
  integration_http_method = each.value.integration_type == "MOCK" ? null : each.value.integration_http_method
  uri                     = coalesce(each.value.lambda_invoke_arn, each.value.integration_uri)
}

resource "aws_cloudwatch_log_group" "access" {
  name              = format("/aws/apigateway/%s/%s", var.name, var.stage_name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
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
