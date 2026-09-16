# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name       = "plan-test"
  subnet_ids = { "us-east-1a" = "subnet-0aaaaaaaaaaaaaaa1" }
}

run "allows_mounting_and_denies_plain_transport" {
  command = plan

  assert {
    condition     = [for statement in data.aws_iam_policy_document.this.statement : statement.effect] == ["Allow", "Deny"]
    error_message = "The policy should allow mounting and deny non-TLS access, since it replaces the default policy."
  }

  assert {
    condition     = toset(data.aws_iam_policy_document.this.statement[0].actions) == toset(["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"])
    error_message = "Clients should be allowed to mount and write, without root access by default."
  }

  assert {
    condition     = one([for condition in data.aws_iam_policy_document.this.statement[0].condition : condition.variable]) == "elasticfilesystem:AccessedViaMountTarget"
    error_message = "Mounting should be allowed only through a mount target."
  }
}

run "allows_root_access_when_asked" {
  command = plan

  variables {
    allow_client_root_access = true
  }

  assert {
    condition     = contains(data.aws_iam_policy_document.this.statement[0].actions, "elasticfilesystem:ClientRootAccess")
    error_message = "Root access should be granted when allow_client_root_access is true."
  }
}
