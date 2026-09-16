# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name = "plan-test"
}

run "attaches_no_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_policy.this) == 0 && length(data.aws_iam_policy_document.this) == 0
    error_message = "With no services and no policy, the topic must keep its default policy."
  }
}

run "lets_services_publish_from_this_account" {
  command = plan

  variables {
    publishing_services = ["cloudwatch.amazonaws.com", "backup.amazonaws.com"]
  }

  assert {
    condition     = length(aws_sns_topic_policy.this) == 1
    error_message = "Naming publishing services must attach a topic policy."
  }

  assert {
    condition     = [for statement in data.aws_iam_policy_document.this[0].statement : statement.sid] == ["AllowServicePublishBySourceAccount", "AllowServicePublishBySourceOwner"]
    error_message = "The service grant must have one statement per source account key."
  }

  assert {
    condition     = alltrue([for statement in data.aws_iam_policy_document.this[0].statement : statement.actions == toset(["sns:Publish"])])
    error_message = "The service grant must allow publishing and nothing else."
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.this[0].statement :
      toset(one(statement.principals).identifiers) == toset(["cloudwatch.amazonaws.com", "backup.amazonaws.com"])
    ])
    error_message = "Both statements must name exactly the publishing services, so each service is granted under either key."
  }

  assert {
    condition = jsonencode([
      for statement in data.aws_iam_policy_document.this[0].statement :
      [for condition in statement.condition : [condition.test, condition.variable, tolist(condition.values)]]
      ]) == jsonencode([
      [["StringEquals", "aws:SourceAccount", ["123456789012"]]],
      [["StringEquals", "aws:SourceOwner", ["123456789012"]]],
    ])
    error_message = "Each statement must require this account under its own key and add no other condition."
  }
}

run "limits_services_to_source_arns" {
  command = plan

  variables {
    publishing_services    = ["events.amazonaws.com"]
    publishing_source_arns = ["arn:aws:events:us-east-1:123456789012:rule/plan-test"]
  }

  assert {
    condition = alltrue([
      for statement in data.aws_iam_policy_document.this[0].statement :
      toset(one([for condition in statement.condition : condition.values if condition.variable == "aws:SourceArn" && condition.test == "ArnLike"])) == toset(["arn:aws:events:us-east-1:123456789012:rule/plan-test"])
    ])
    error_message = "Source ARNs must limit both statements by aws:SourceArn."
  }
}

run "merges_the_service_grant_into_the_caller_policy" {
  command = plan

  variables {
    publishing_services = ["cloudwatch.amazonaws.com"]
    attach_policy       = true
    policy_json         = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }

  assert {
    condition     = length(aws_sns_topic_policy.this) == 1 && tolist(data.aws_iam_policy_document.this[0].source_policy_documents) == tolist(["{\"Version\":\"2012-10-17\",\"Statement\":[]}"])
    error_message = "The caller's policy must be merged with the service grant into one topic policy."
  }
}
