# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name               = "plan-test"
  source_bucket_arn  = "arn:aws:s3:::plan-test-dags"
  execution_role_arn = "arn:aws:iam::123456789012:role/plan-test-mwaa"
  subnet_ids         = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  security_group_ids = ["sg-0ccccccccccccccc3"]
}

run "plans_a_micro_environment_with_one_of_each" {
  command = plan

  variables {
    environment_class = "mw1.micro"
    schedulers        = 1
    min_workers       = 1
    max_workers       = 1
  }

  assert {
    condition     = aws_mwaa_environment.this.schedulers == 1 && aws_mwaa_environment.this.max_workers == 1
    error_message = "A micro environment should plan with one scheduler and one worker."
  }
}

run "plans_a_small_environment_with_defaults" {
  command = plan
}

run "refuses_two_schedulers_on_micro" {
  command = plan

  variables {
    environment_class = "mw1.micro"
    min_workers       = 1
    max_workers       = 1
  }

  expect_failures = [var.schedulers]
}

run "refuses_worker_scaling_on_micro" {
  command = plan

  variables {
    environment_class = "mw1.micro"
    schedulers        = 1
    min_workers       = 1
  }

  expect_failures = [var.max_workers]
}
