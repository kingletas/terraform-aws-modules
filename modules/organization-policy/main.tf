resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = var.type
  content     = var.content

  skip_destroy = var.skip_destroy

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = var.targets

  policy_id = aws_organizations_policy.this.id
  target_id = each.value

  skip_destroy = var.skip_destroy
}
