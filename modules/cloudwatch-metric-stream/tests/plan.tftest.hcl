# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  role_arn     = "arn:aws:iam::123456789012:role/metric-stream"
  firehose_arn = "arn:aws:firehose:us-east-1:123456789012:deliverystream/plan-test"
}

run "plans_an_include_list" {
  command = plan

  variables {
    name = "plan-test"

    include_namespaces = {
      "AWS/EC2"            = []
      "AWS/ApplicationELB" = ["RequestCount", "TargetResponseTime", "HTTPCode_Target_5XX_Count"]
    }

    statistics_configurations = {
      latency = {
        additional_statistics = ["p95", "p99"]
        metrics               = [{ namespace = "AWS/ApplicationELB", metric_name = "TargetResponseTime" }]
      }
    }

    tags = { ManagedBy = "terraform" }
  }
}

run "plans_an_exclude_list" {
  command = plan

  variables {
    name               = "plan-test-exclude"
    exclude_namespaces = { "AWS/Usage" = [] }
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_an_include_and_an_exclude_together" {
  command = plan

  variables {
    name               = "plan-test"
    include_namespaces = { "AWS/EC2" = [] }
    exclude_namespaces = { "AWS/Usage" = [] }
  }

  expect_failures = [aws_cloudwatch_metric_stream.this]
}

run "refuses_a_statistics_configuration_with_no_metrics" {
  command = plan

  variables {
    name = "plan-test"

    statistics_configurations = {
      latency = { additional_statistics = ["p99"], metrics = [] }
    }
  }

  expect_failures = [var.statistics_configurations]
}

run "refuses_an_output_format_cloudwatch_does_not_emit" {
  command = plan

  variables {
    name          = "plan-test"
    output_format = "protobuf"
  }

  expect_failures = [var.output_format]
}
