# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name        = "deny-leaving-the-organization"
    description = "No member account may remove itself from the organization."

    content = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "DenyLeaveOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = "*"
      }]
    })

    targets = {
      root     = "r-a1b2"
      workload = "ou-a1b2-abcd1234"
      sandbox  = "123456789012"
    }

    tags = { ManagedBy = "terraform" }
  }
}

# Refusal tests: each run below must fail the plan.
run "refuses_content_that_is_not_json" {
  command = plan

  variables {
    name        = "broken"
    description = "Content that never parsed."
    content     = "Deny organizations:LeaveOrganization"
  }

  expect_failures = [var.content]
}

run "refuses_a_target_that_is_not_an_aws_identifier" {
  command = plan

  variables {
    name        = "broken"
    description = "A target named rather than identified."
    content     = "{}"
    targets     = { workload = "workload" }
  }

  expect_failures = [var.targets]
}
