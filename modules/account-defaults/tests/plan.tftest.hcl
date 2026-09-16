# Plans the module with IDs from resources created in the same plan, which are
# unknown until apply, which a for_each or count must not depend on.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_ids_unknown_until_apply" {
  command = plan

  module {
    source = "./tests/fixture"
  }

  assert {
    condition     = keys(module.under_test.locked_default_security_group_ids) == ["main"]
    error_message = "A VPC ID unknown until apply should still lock that VPC's default security group, keyed by its name."
  }

  assert {
    condition     = module.under_test.ebs_encryption_by_default && module.under_test.s3_public_access_blocked
    error_message = "EBS encryption by default and the account public access block should be on by default."
  }
}

run "applies_secure_defaults" {
  command = plan

  variables {
    default_security_group_vpc_ids = { main = "vpc-0aaaaaaaaaaaaaaa1" }
  }

  assert {
    condition     = aws_ebs_encryption_by_default.this.enabled && length(aws_ebs_default_kms_key.this) == 0
    error_message = "New volumes should be encrypted, with the AWS-managed key unless one is given."
  }

  assert {
    condition = (
      aws_s3_account_public_access_block.this[0].block_public_acls &&
      aws_s3_account_public_access_block.this[0].block_public_policy &&
      aws_s3_account_public_access_block.this[0].ignore_public_acls &&
      aws_s3_account_public_access_block.this[0].restrict_public_buckets
    )
    error_message = "Every part of the account public access block should be on."
  }

  assert {
    condition     = aws_iam_account_password_policy.this[0].minimum_password_length == 14 && aws_iam_account_password_policy.this[0].password_reuse_prevention == 24
    error_message = "The password policy should require 14 characters and refuse the last 24 passwords."
  }

  assert {
    condition     = aws_default_security_group.this["main"].vpc_id == "vpc-0aaaaaaaaaaaaaaa1"
    error_message = "Each named VPC should have its default security group adopted."
  }
}

run "leaves_settings_alone_when_turned_off" {
  command = plan

  variables {
    block_s3_public_access = false
    password_policy        = null
  }

  assert {
    condition     = length(aws_s3_account_public_access_block.this) == 0 && length(aws_iam_account_password_policy.this) == 0
    error_message = "Turning a setting off should manage nothing for it."
  }
}
