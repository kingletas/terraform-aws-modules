data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Regional, and it applies to every volume created afterwards regardless of what
# asked for it. Existing volumes are untouched.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = var.ebs_encryption_by_default
}

resource "aws_ebs_default_kms_key" "this" {
  count = var.ebs_default_kms_key == null ? 0 : 1

  key_arn = var.ebs_default_kms_key.arn
}

# Account-wide, and it sits above each bucket's own block. A bucket policy
# cannot open a bucket while this stands.
resource "aws_s3_account_public_access_block" "this" {
  count = var.block_s3_public_access ? 1 : 0

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_account_password_policy" "this" {
  # checkov:skip=CKV_AWS_11: require_lowercase defaults true inside the policy object
  # checkov:skip=CKV_AWS_12: require_numbers defaults true inside the policy object
  # checkov:skip=CKV_AWS_14: require_symbols defaults true inside the policy object
  # checkov:skip=CKV_AWS_15: require_uppercase defaults true inside the policy object
  # checkov:skip=CKV_AWS_9: expiry is off deliberately; NIST stopped recommending forced rotation, and length plus a second factor do the work
  count = var.password_policy == null ? 0 : 1

  minimum_password_length        = var.password_policy.minimum_length
  require_lowercase_characters   = var.password_policy.require_lowercase
  require_uppercase_characters   = var.password_policy.require_uppercase
  require_numbers                = var.password_policy.require_numbers
  require_symbols                = var.password_policy.require_symbols
  allow_users_to_change_password = var.password_policy.allow_users_to_change
  password_reuse_prevention      = var.password_policy.reuse_prevention

  max_password_age = var.password_policy.max_age_days == 0 ? null : var.password_policy.max_age_days
  hard_expiry      = var.password_policy.max_age_days == 0 ? null : var.password_policy.hard_expiry
}

# Adopting a default security group and giving it no rules is the only way to
# make it permit nothing; it cannot be deleted.
resource "aws_default_security_group" "this" {
  for_each = var.default_security_group_vpc_ids

  vpc_id = each.value

  tags = {
    Name      = "default-locked"
    ManagedBy = "terraform"
  }
}
