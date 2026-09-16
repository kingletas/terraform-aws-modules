# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "merges_caller_statements_into_the_one_bucket_policy" {
  command = plan

  variables {
    name             = "plan-test-bucket"
    policy_documents = ["{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AllowPlanTest\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"cloudfront.amazonaws.com\"},\"Action\":\"s3:GetObject\",\"Resource\":\"*\"}]}"]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this.source_policy_documents) == 1
    error_message = "The caller's policy document must be merged into the module's bucket policy."
  }

  assert {
    condition     = data.aws_iam_policy_document.this.statement[0].sid == "DenyInsecureTransport"
    error_message = "The TLS-only deny must stay in the bucket policy."
  }
}

run "writes_only_the_tls_deny_without_caller_statements" {
  command = plan

  variables {
    name = "plan-test-bucket"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this.source_policy_documents) == 0
    error_message = "No caller statements means no source documents."
  }
}
