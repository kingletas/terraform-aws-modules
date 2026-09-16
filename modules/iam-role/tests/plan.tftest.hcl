# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name = "plan-test"
}

run "plans_a_github_oidc_role" {
  command = plan

  variables {
    trusted_oidc_providers = {
      github_actions = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        audience_key = "token.actions.githubusercontent.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "token.actions.githubusercontent.com:sub"
        subjects     = ["repo:example-org/app:ref:refs/heads/main", "repo:example-org/*"]
      }
    }
    managed_policy_arns = { read_only = "arn:aws:iam::aws:policy/ReadOnlyAccess" }
  }

  assert {
    condition     = keys(aws_iam_role_policy_attachment.this) == ["read_only"]
    error_message = "The managed policy should be attached under its key."
  }

  assert {
    condition     = local.oidc_statement_ids["github_actions"] == "TrustOidcGithubActions"
    error_message = "A statement ID must hold only letters and digits."
  }
}

run "plans_a_non_github_oidc_role" {
  command = plan

  variables {
    trusted_oidc_providers = {
      "eks-cluster" = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
        audience_key = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE:sub"
        subjects     = ["system:serviceaccount:app:worker"]
      }
    }
  }
}

run "refuses_an_oidc_trust_with_no_subjects" {
  command = plan

  variables {
    trusted_oidc_providers = {
      github = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        audience_key = "token.actions.githubusercontent.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "token.actions.githubusercontent.com:sub"
        subjects     = []
      }
    }
  }

  expect_failures = [var.trusted_oidc_providers]
}

run "refuses_a_bare_wildcard_subject" {
  command = plan

  variables {
    trusted_oidc_providers = {
      issuer = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/issuer.example.com"
        audience_key = "issuer.example.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "issuer.example.com:sub"
        subjects     = ["*"]
      }
    }
  }

  expect_failures = [var.trusted_oidc_providers]
}

run "refuses_a_wildcard_github_owner" {
  command = plan

  variables {
    trusted_oidc_providers = {
      github = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        audience_key = "token.actions.githubusercontent.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "token.actions.githubusercontent.com:sub"
        subjects     = ["repo:*"]
      }
    }
  }

  expect_failures = [var.trusted_oidc_providers]
}

run "refuses_a_partly_wildcarded_github_owner" {
  command = plan

  variables {
    trusted_oidc_providers = {
      github = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        audience_key = "token.actions.githubusercontent.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "token.actions.githubusercontent.com:sub"
        subjects     = ["repo:example-*/app:*"]
      }
    }
  }

  expect_failures = [var.trusted_oidc_providers]
}

run "refuses_keys_that_collide_as_statement_ids" {
  command = plan

  variables {
    trusted_oidc_providers = {
      "ci-deploy" = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/issuer.example.com"
        audience_key = "issuer.example.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "issuer.example.com:sub"
        subjects     = ["deploy"]
      }
      ci_deploy = {
        provider_arn = "arn:aws:iam::123456789012:oidc-provider/issuer.example.com"
        audience_key = "issuer.example.com:aud"
        audiences    = ["sts.amazonaws.com"]
        subject_key  = "issuer.example.com:sub"
        subjects     = ["deploy"]
      }
    }
  }

  expect_failures = [var.trusted_oidc_providers]
}

run "gives_every_output_once_policies_are_attached" {
  command = apply

  variables {
    trusted_services        = ["ec2.amazonaws.com"]
    managed_policy_arns     = { ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
    create_instance_profile = true
  }

  assert {
    condition     = output.name == aws_iam_role.this.name && output.id == aws_iam_role.this.id
    error_message = "The name and id outputs should be the role's own."
  }

  assert {
    condition     = output.instance_profile_name == aws_iam_instance_profile.this[0].name
    error_message = "The instance profile output should be the profile this module created."
  }
}
