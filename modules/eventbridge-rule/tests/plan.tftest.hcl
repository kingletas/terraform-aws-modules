# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name                = "plan-test"
  schedule_expression = "rate(1 hour)"
}

run "plans_targets_each_shaping_their_input_one_way" {
  command = plan

  variables {
    targets = {
      constant = {
        arn   = "arn:aws:lambda:us-east-1:123456789012:function:plan-test"
        input = "{\"source\":\"schedule\"}"
      }
      transformed = {
        arn = "arn:aws:sqs:us-east-1:123456789012:plan-test"
        input_transformer = {
          input_paths    = { time = "$.time" }
          input_template = "{\"at\":<time>}"
        }
      }
    }
  }

  assert {
    condition     = aws_cloudwatch_event_target.this["transformed"].input == null
    error_message = "A transformer target must carry no constant input."
  }
}

run "refuses_a_target_with_input_and_input_path" {
  command = plan

  variables {
    targets = {
      both = {
        arn        = "arn:aws:lambda:us-east-1:123456789012:function:plan-test"
        input      = "{}"
        input_path = "$.detail"
      }
    }
  }

  expect_failures = [var.targets]
}

run "refuses_a_target_with_input_and_a_transformer" {
  command = plan

  variables {
    targets = {
      both = {
        arn   = "arn:aws:lambda:us-east-1:123456789012:function:plan-test"
        input = "{}"
        input_transformer = {
          input_paths    = { time = "$.time" }
          input_template = "{\"at\":<time>}"
        }
      }
    }
  }

  expect_failures = [var.targets]
}
