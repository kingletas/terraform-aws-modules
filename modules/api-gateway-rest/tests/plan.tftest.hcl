# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name = "plan-test"
}

run "builds_a_nested_resource_tree" {
  command = plan

  variables {
    routes = {
      list_orders = {
        path              = "/orders"
        method            = "GET"
        authorization     = "AWS_IAM"
        lambda_invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:plan-test/invocations"
      }
      get_order = {
        path              = "/orders/{id}"
        method            = "GET"
        authorization     = "AWS_IAM"
        lambda_invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:plan-test/invocations"
      }
      order_items = {
        path              = "orders/{id}/items/"
        method            = "GET"
        authorization     = "AWS_IAM"
        lambda_invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:plan-test/invocations"
      }
      health = {
        path             = "/"
        method           = "GET"
        authorization    = "NONE"
        integration_type = "MOCK"
      }
    }
  }

  assert {
    condition     = keys(aws_api_gateway_resource.level_1) == ["orders"]
    error_message = "The first level should hold one resource per distinct top segment."
  }

  assert {
    condition     = aws_api_gateway_resource.level_2["orders/{id}"].path_part == "{id}"
    error_message = "A nested resource should carry only its own segment."
  }

  assert {
    condition     = keys(aws_api_gateway_resource.level_3) == ["orders/{id}/items"]
    error_message = "The third level should hold the items resource."
  }

  assert {
    condition     = local.resource_levels[2]["orders/{id}/items"].parent == "orders/{id}"
    error_message = "A nested resource should name its parent prefix."
  }

  assert {
    condition     = local.route_paths["health"] == ""
    error_message = "The root route should attach to the root resource."
  }

  assert {
    condition     = aws_api_gateway_integration.this["health"].uri == null
    error_message = "A MOCK integration has no URI."
  }

  assert {
    condition     = length(aws_api_gateway_account.this) == 0
    error_message = "The account logging role is opt-in."
  }
}

run "creates_the_account_logging_role_when_asked" {
  command = plan

  variables {
    manage_account_cloudwatch_role = true
    routes = {
      health = {
        path             = "/health"
        method           = "GET"
        authorization    = "NONE"
        integration_type = "MOCK"
      }
    }
  }

  assert {
    condition     = length(aws_api_gateway_account.this) == 1
    error_message = "The account logging setting should be managed when asked."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.account_logging[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
    error_message = "The logging role should carry the managed push policy in the current partition."
  }
}

run "refuses_a_path_with_an_empty_segment" {
  command = plan

  variables {
    routes = {
      health = {
        path             = "/orders//items"
        method           = "GET"
        authorization    = "NONE"
        integration_type = "MOCK"
      }
    }
  }

  expect_failures = [var.routes]
}

run "refuses_a_non_mock_route_with_no_target" {
  command = plan

  variables {
    routes = {
      orders = {
        path          = "/orders"
        method        = "GET"
        authorization = "NONE"
      }
    }
  }

  expect_failures = [var.routes]
}
