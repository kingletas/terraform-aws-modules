# SES SMTP credentials are an IAM access key run through a derivation the
# provider does for us. There is no role-based alternative: SMTP authenticates
# with a username and password and has nowhere to put a session token. An
# application that can call the SES API should use a role and leave this off.
resource "aws_iam_user" "smtp" {
  count = var.create_smtp_user ? 1 : 0

  name = local.smtp_user_name
  path = "/ses/"

  tags = local.tags
}

resource "aws_iam_access_key" "smtp" {
  count = var.create_smtp_user ? 1 : 0

  user = aws_iam_user.smtp[0].name
}

data "aws_iam_policy_document" "smtp" {
  count = var.create_smtp_user ? 1 : 0

  statement {
    sid       = "SendThroughThisIdentityOnly"
    effect    = "Allow"
    actions   = ["ses:SendRawEmail", "ses:SendEmail"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = [format("*@%s", var.domain)]
    }
  }
}

resource "aws_iam_user_policy" "smtp" {
  count = var.create_smtp_user ? 1 : 0

  name   = "send-email"
  user   = aws_iam_user.smtp[0].name
  policy = data.aws_iam_policy_document.smtp[0].json
}
