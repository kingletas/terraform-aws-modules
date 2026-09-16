# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name           = "plan-test"
  s3_bucket_name = "plan-test-trail-bucket"
}

run "keeps_the_default_selector_with_no_data_events" {
  command = plan

  assert {
    condition     = length(aws_cloudtrail.this.advanced_event_selector) == 0
    error_message = "A trail with no data events should keep the default management selector."
  }
}

run "selects_management_events_alongside_data_events" {
  command = plan

  variables {
    data_events = {
      uploads = {
        resource_type   = "AWS::S3::Object"
        resource_values = ["arn:aws:s3:::plan-test-uploads/"]
        read_write_type = "WriteOnly"
      }
    }
  }

  assert {
    condition     = contains([for selector in aws_cloudtrail.this.advanced_event_selector : selector.name], "management-events")
    error_message = "Data events must not stop the trail recording management events."
  }

  assert {
    condition = anytrue([
      for selector in aws_cloudtrail.this.advanced_event_selector : selector.name == "uploads" && anytrue([
        for field in selector.field_selector : field.field == "readOnly" && contains(field.equals, "false")
      ])
    ])
    error_message = "A WriteOnly data event must select readOnly false."
  }
}

run "drops_management_events_when_asked" {
  command = plan

  variables {
    include_management_events = false
    data_events = {
      uploads = {
        resource_type   = "AWS::S3::Object"
        resource_values = ["arn:aws:s3:::plan-test-uploads/"]
      }
    }
  }

  assert {
    condition     = [for selector in aws_cloudtrail.this.advanced_event_selector : selector.name] == ["uploads"]
    error_message = "Only the data event selector should remain."
  }
}

run "filters_management_events_by_read_write_type" {
  command = plan

  variables {
    management_events_read_write_type = "WriteOnly"
  }

  assert {
    condition     = length(aws_cloudtrail.this.advanced_event_selector) == 1
    error_message = "A WriteOnly management filter needs an advanced selector."
  }
}

run "refuses_a_trail_that_records_nothing" {
  command = plan

  variables {
    include_management_events = false
  }

  expect_failures = [aws_cloudtrail.this]
}

run "refuses_an_unknown_read_write_type" {
  command = plan

  variables {
    management_events_read_write_type = "Writes"
  }

  expect_failures = [var.management_events_read_write_type]
}
