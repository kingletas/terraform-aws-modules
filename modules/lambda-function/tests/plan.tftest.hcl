# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name      = "plan-test"
  role_arn  = "arn:aws:iam::123456789012:role/plan-test-function"
  s3_bucket = "plan-test-artifacts"
  s3_key    = "plan-test/v1.0.0.zip"
  handler   = "index.handler"
  runtime   = "python3.13"
}

run "passes_traces_through_by_default" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.tracing_config[0].mode == "PassThrough"
    error_message = "Tracing should not require X-Ray permissions the module does not grant."
  }
}

run "starts_traces_when_asked" {
  command = plan

  variables {
    tracing_mode = "Active"
  }

  assert {
    condition     = aws_lambda_function.this.tracing_config[0].mode == "Active"
    error_message = "Active tracing should be honoured when asked for."
  }
}
