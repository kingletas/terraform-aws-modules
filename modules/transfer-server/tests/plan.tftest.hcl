# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name        = "plan-test"
  bucket_name = "plan-test-exchange"
}

run "scopes_each_user_to_its_home_directory" {
  command = plan

  variables {
    bucket_kms_key = { arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000" }

    users = {
      partner-acme = {
        public_keys = {
          primary  = "ssh-ed25519 AAAAplan-test-placeholder partner-acme"
          rotation = "ssh-ed25519 AAAAplan-test-placeholder partner-acme-next"
        }
        home_directory = "/inbound/acme/"
      }
      partner-readonly = {
        public_keys = { primary = "ssh-ed25519 AAAAplan-test-placeholder partner-readonly" }
        read_only   = true
      }
    }
  }

  assert {
    condition     = local.user_prefixes["partner-acme"] == "inbound/acme"
    error_message = "A set home directory should become the policy prefix."
  }

  assert {
    condition     = local.user_prefixes["partner-readonly"] == "partner-readonly"
    error_message = "Without a home directory the prefix is the username."
  }

  assert {
    condition     = one(aws_transfer_user.this["partner-acme"].home_directory_mappings).target == "/plan-test-exchange/inbound/acme"
    error_message = "The home directory mapping should use the same prefix as the policy."
  }

  assert {
    condition     = [for statement in data.aws_iam_policy_document.user["partner-acme"].statement : statement.sid] == ["ListOwnPrefix", "ReadOwnPrefix", "WriteOwnPrefix", "UseBucketKeyThroughS3"]
    error_message = "A writing user of a KMS-encrypted bucket should be granted the key."
  }

  assert {
    condition     = one([for statement in data.aws_iam_policy_document.user["partner-readonly"].statement : statement.actions if statement.sid == "UseBucketKeyThroughS3"]) == toset(["kms:Decrypt"])
    error_message = "A read-only user should only be able to decrypt."
  }

  assert {
    condition     = toset(keys(aws_transfer_ssh_key.this)) == toset(["partner-acme/primary", "partner-acme/rotation", "partner-readonly/primary"])
    error_message = "Each key should be addressed by its user and the name the caller gave it."
  }

  assert {
    condition     = aws_transfer_ssh_key.this["partner-acme/rotation"].user_name == "partner-acme"
    error_message = "A key should be attached to the user whose map it came from."
  }
}

run "grants_no_key_without_one" {
  command = plan

  variables {
    users = {
      partner-acme = {
        public_keys = { primary = "ssh-ed25519 AAAAplan-test-placeholder partner-acme" }
      }
    }
  }

  assert {
    condition     = length([for statement in data.aws_iam_policy_document.user["partner-acme"].statement : statement if statement.sid == "UseBucketKeyThroughS3"]) == 0
    error_message = "No key statement should exist without a bucket key."
  }
}

run "refuses_a_home_directory_at_the_bucket_root" {
  command = plan

  variables {
    users = {
      partner-acme = {
        public_keys    = { primary = "ssh-ed25519 AAAAplan-test-placeholder partner-acme" }
        home_directory = "/"
      }
    }
  }

  expect_failures = [var.users]
}

run "refuses_a_key_name_carrying_the_address_separator" {
  command = plan

  variables {
    users = {
      partner-acme = {
        public_keys = { "acme/primary" = "ssh-ed25519 AAAAplan-test-placeholder partner-acme" }
      }
    }
  }

  expect_failures = [var.users]
}
