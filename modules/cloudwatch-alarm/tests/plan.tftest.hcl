# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_a_metric_alarm_and_a_maths_alarm" {
  command = plan

  variables {
    alarms = {
      plan-test-cpu = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/EC2"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80
      }

      plan-test-error-rate = {
        comparison_operator = "GreaterThanThreshold"
        threshold           = 5
        metric_query = [
          { id = "errors", metric_name = "5XXError", namespace = "AWS/ApiGateway", stat = "Sum" },
          { id = "requests", metric_name = "Count", namespace = "AWS/ApiGateway", stat = "Sum" },
          { id = "rate", expression = "errors / requests * 100", label = "5xx rate", return_data = true },
        ]
      }
    }
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.this["plan-test-error-rate"].metric_query) == 3
    error_message = "The maths alarm should carry all three queries."
  }
}

run "refuses_a_maths_alarm_returning_no_series" {
  command = plan

  variables {
    alarms = {
      plan-test-error-rate = {
        comparison_operator = "GreaterThanThreshold"
        threshold           = 5
        metric_query = [
          { id = "errors", metric_name = "5XXError", namespace = "AWS/ApiGateway", stat = "Sum" },
          { id = "rate", expression = "errors * 100", label = "5xx rate" },
        ]
      }
    }
  }

  expect_failures = [var.alarms]
}

run "refuses_a_maths_alarm_returning_two_series" {
  command = plan

  variables {
    alarms = {
      plan-test-error-rate = {
        comparison_operator = "GreaterThanThreshold"
        threshold           = 5
        metric_query = [
          { id = "errors", metric_name = "5XXError", namespace = "AWS/ApiGateway", stat = "Sum", return_data = true },
          { id = "rate", expression = "errors * 100", label = "5xx rate", return_data = true },
        ]
      }
    }
  }

  expect_failures = [var.alarms]
}

run "accepts_a_one_day_evaluation_window" {
  command = plan

  variables {
    alarms = {
      plan-test-daily = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/EC2"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80
        period              = 3600
        evaluation_periods  = 24
      }

      plan-test-high-resolution = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/EC2"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80
        period              = 10
        evaluation_periods  = 360
      }
    }
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["plan-test-daily"].evaluation_periods == 24
    error_message = "An evaluation window of exactly one day must plan."
  }
}

run "refuses_an_evaluation_window_over_one_day" {
  command = plan

  variables {
    alarms = {
      plan-test-daily = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/EC2"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80
        period              = 3600
        evaluation_periods  = 25
      }
    }
  }

  expect_failures = [var.alarms]
}

run "refuses_a_high_resolution_window_over_one_hour" {
  command = plan

  variables {
    alarms = {
      plan-test-high-resolution = {
        metric_name         = "CPUUtilization"
        namespace           = "AWS/EC2"
        comparison_operator = "GreaterThanThreshold"
        threshold           = 80
        period              = 30
        evaluation_periods  = 121
      }
    }
  }

  expect_failures = [var.alarms]
}

run "refuses_a_maths_alarm_whose_metric_window_is_over_one_day" {
  command = plan

  variables {
    alarms = {
      plan-test-error-rate = {
        comparison_operator = "GreaterThanThreshold"
        threshold           = 5
        evaluation_periods  = 2
        metric_query = [
          { id = "errors", metric_name = "5XXError", namespace = "AWS/ApiGateway", stat = "Sum", period = 86400 },
          { id = "rate", expression = "errors * 100", label = "5xx rate", return_data = true },
        ]
      }
    }
  }

  expect_failures = [var.alarms]
}
