locals {
  in_vpc = var.endpoint_type == "VPC"
  tags   = merge(var.tags, { Name = var.name })

  # The prefix each user's home directory maps to, which the user's policy is scoped to.
  user_prefixes = {
    for username, user in var.users : username => user.home_directory == null ? username : trim(user.home_directory, "/")
  }
}

data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = format("/aws/transfer/%s", var.name)
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.tags
}

data "aws_iam_policy_document" "logging_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "logging" {
  name_prefix        = format("%s-log-", substr(var.name, 0, 20))
  assume_role_policy = data.aws_iam_policy_document.logging_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "logging" {
  role       = aws_iam_role.logging.name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AWSTransferLoggingAccess", data.aws_partition.current.partition)
}

resource "aws_transfer_server" "this" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = var.protocols
  endpoint_type          = var.endpoint_type
  security_policy_name   = var.security_policy_name
  certificate            = var.certificate_arn
  logging_role           = aws_iam_role.logging.arn

  dynamic "endpoint_details" {
    for_each = local.in_vpc ? [1] : []

    content {
      vpc_id                 = var.vpc_id
      subnet_ids             = var.subnet_ids
      security_group_ids     = var.security_group_ids
      address_allocation_ids = var.address_allocation_ids
    }
  }

  structured_log_destinations = [format("%s:*", aws_cloudwatch_log_group.this.arn)]

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !contains(var.protocols, "FTPS") || var.certificate_arn != null
      error_message = "FTPS needs a certificate_arn."
    }

    precondition {
      condition     = !local.in_vpc || (var.vpc_id != null && length(var.subnet_ids) > 0)
      error_message = "A VPC endpoint needs vpc_id and at least one subnet."
    }
  }
}

# Each user is scoped to its home directory prefix and cannot list the bucket root.
data "aws_iam_policy_document" "user" {
  for_each = var.users

  statement {
    sid       = "ListOwnPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [format("arn:%s:s3:::%s", data.aws_partition.current.partition, var.bucket_name)]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [format("%s/*", local.user_prefixes[each.key]), local.user_prefixes[each.key]]
    }
  }

  statement {
    sid    = "ReadOwnPrefix"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectACL",
    ]

    resources = [format("arn:%s:s3:::%s/%s/*", data.aws_partition.current.partition, var.bucket_name, local.user_prefixes[each.key])]
  }

  dynamic "statement" {
    for_each = each.value.read_only ? [] : [1]

    content {
      sid    = "WriteOwnPrefix"
      effect = "Allow"

      actions = [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
      ]

      resources = [format("arn:%s:s3:::%s/%s/*", data.aws_partition.current.partition, var.bucket_name, local.user_prefixes[each.key])]
    }
  }

  dynamic "statement" {
    for_each = var.bucket_kms_key == null ? [] : [var.bucket_kms_key]

    content {
      sid       = "UseBucketKeyThroughS3"
      effect    = "Allow"
      actions   = each.value.read_only ? ["kms:Decrypt"] : ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [statement.value.arn]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = [format("s3.%s.%s", data.aws_region.current.region, data.aws_partition.current.dns_suffix)]
      }
    }
  }
}

data "aws_iam_policy_document" "user_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "user" {
  for_each = var.users

  name_prefix        = format("%s-%s-", substr(var.name, 0, 12), substr(each.key, 0, 8))
  assume_role_policy = data.aws_iam_policy_document.user_assume_role.json

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}

resource "aws_iam_role_policy" "user" {
  for_each = var.users

  name_prefix = "s3-access-"
  role        = aws_iam_role.user[each.key].id
  policy      = data.aws_iam_policy_document.user[each.key].json
}

resource "aws_transfer_user" "this" {
  for_each = var.users

  server_id = aws_transfer_server.this.id
  user_name = each.key
  role      = aws_iam_role.user[each.key].arn

  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = format("/%s/%s", var.bucket_name, local.user_prefixes[each.key])
  }

  dynamic "posix_profile" {
    for_each = each.value.posix_uid == null ? [] : [each.value]

    content {
      uid = posix_profile.value.posix_uid
      gid = posix_profile.value.posix_gid
    }
  }

  tags = merge(var.tags, { Name = each.key })
}

# Keyed "username/key_name", so rotating one key leaves every other key alone
# and a key that moves between users can be named in a moved block.
resource "aws_transfer_ssh_key" "this" {
  for_each = merge([
    for username, user in var.users : {
      for key_name, key in user.public_keys :
      format("%s/%s", username, key_name) => { username = username, body = key }
    }
  ]...)

  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.this[each.value.username].user_name
  body      = each.value.body
}
