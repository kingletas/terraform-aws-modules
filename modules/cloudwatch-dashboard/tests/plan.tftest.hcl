# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "leaves_unplaced_widgets_to_cloudwatch" {
  command = plan

  variables {
    name = "plan-test"
    widgets = [
      { type = "text", width = 12, markdown = "# Plan test" },
      { title = "Requests", width = 8, metrics_json = "[[\"AWS/ApplicationELB\",\"RequestCount\"]]" },
      { title = "Errors", width = 8, metrics_json = "[[\"AWS/ApplicationELB\",\"HTTPCode_ELB_5XX_Count\"]]" },
    ]
  }

  assert {
    condition = alltrue([
      for widget in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets :
      !contains(keys(widget), "x") && !contains(keys(widget), "y")
    ])
    error_message = "An unplaced widget must carry no coordinates, so CloudWatch wraps it instead of pushing it past column 24."
  }
}

run "keeps_a_placed_widget_where_it_was_put" {
  command = plan

  variables {
    name    = "plan-test"
    widgets = [{ type = "text", width = 8, x = 16, y = 4, markdown = "# Plan test" }]
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].x == 16 && jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].y == 4
    error_message = "A placed widget must keep the coordinates it was given."
  }
}

run "refuses_x_without_y" {
  command = plan

  variables {
    name    = "plan-test"
    widgets = [{ type = "text", width = 8, x = 16, markdown = "# Plan test" }]
  }

  expect_failures = [var.widgets]
}

run "refuses_a_placed_widget_past_the_grid" {
  command = plan

  variables {
    name    = "plan-test"
    widgets = [{ type = "text", width = 12, x = 16, y = 0, markdown = "# Plan test" }]
  }

  expect_failures = [var.widgets]
}

run "links_to_the_commercial_console" {
  command = plan

  variables {
    name    = "plan-test"
    widgets = [{ type = "text", width = 8, markdown = "# Plan test" }]
  }

  assert {
    condition     = output.url == "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=plan-test"
    error_message = "The console URL must use the commercial console hostname in the aws partition."
  }
}

run "links_to_the_govcloud_console" {
  command = plan

  variables {
    name           = "plan-test"
    default_region = "us-gov-west-1"
    widgets        = [{ type = "text", width = 8, markdown = "# Plan test" }]
  }

  override_data {
    target = data.aws_partition.current
    values = {
      partition  = "aws-us-gov"
      dns_suffix = "amazonaws.com"
    }
  }

  assert {
    condition     = output.url == "https://console.amazonaws-us-gov.com/cloudwatch/home?region=us-gov-west-1#dashboards:name=plan-test"
    error_message = "The console URL must use the partition's own console hostname."
  }
}

run "gives_no_console_url_in_an_unknown_partition" {
  command = plan

  variables {
    name    = "plan-test"
    widgets = [{ type = "text", width = 8, markdown = "# Plan test" }]
  }

  override_data {
    target = data.aws_partition.current
    values = {
      partition  = "aws-plan-test"
      dns_suffix = "example.internal"
    }
  }

  assert {
    condition     = output.url == null
    error_message = "A partition with no known console should get no URL rather than a wrong one."
  }
}
