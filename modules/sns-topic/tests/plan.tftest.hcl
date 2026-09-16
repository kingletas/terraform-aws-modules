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
    condition     = one(data.aws_iam_policy_document.this[0].statement).actions == toset(["sns:Publish"])
    error_message = "The service grant must allow publishing and nothing else."
  }

  assert {
    condition     = toset(one(one(data.aws_iam_policy_document.this[0].statement).principals).identifiers) == toset(["cloudwatch.amazonaws.com", "backup.amazonaws.com"])
    error_message = "The service grant must name exactly the publishing services."
  }

  assert {
    condition     = toset(one([for condition in one(data.aws_iam_policy_document.this[0].statement).condition : condition.values if condition.variable == "aws:SourceAccount"])) == toset(["123456789012"])
    error_message = "The service grant must be limited to this account."
  }

  assert {
    condition     = length([for condition in one(data.aws_iam_policy_document.this[0].statement).condition : condition if condition.variable == "aws:SourceArn"]) == 0
    error_message = "With no source ARNs, the grant must not add an aws:SourceArn condition."
  }
}

run "limits_services_to_source_arns" {
  command = plan

  variables {
    publishing_services    = ["events.amazonaws.com"]
    publishing_source_arns = ["arn:aws:events:us-east-1:123456789012:rule/plan-test"]
  }

  assert {
    condition     = toset(one([for condition in one(data.aws_iam_policy_document.this[0].statement).condition : condition.values if condition.variable == "aws:SourceArn" && condition.test == "ArnLike"])) == toset(["arn:aws:events:us-east-1:123456789012:rule/plan-test"])
    error_message = "Source ARNs must limit the grant by aws:SourceArn."
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
