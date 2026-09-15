locals {
  # The condition keys on a trust policy are the issuer host, not the URL, so
  # deriving them here keeps the caller from writing the host out twice.
  host = replace(var.url, "https://", "")
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = var.url
  client_id_list  = var.client_ids
  thumbprint_list = var.thumbprints

  tags = merge(var.tags, { Name = local.host })
}
