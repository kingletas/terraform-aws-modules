locals {
  # Each rule is encoded on its own. The two rules have different shapes, and any
  # step that makes them share a type — a conditional, merge or concat — either
  # fails to evaluate or turns countNumber into a string the ECR API rejects.
  untagged_rule = var.untagged_image_expiry_days > 0 ? [jsonencode({
    rulePriority = 1
    description  = "Expire untagged images"
    selection = {
      tagStatus   = "untagged"
      countType   = "sinceImagePushed"
      countUnit   = "days"
      countNumber = var.untagged_image_expiry_days
    }
    action = { type = "expire" }
  })] : []

  tagged_rule = var.max_tagged_images > 0 ? [
    length(var.tag_prefixes_to_keep) > 0
    ? jsonencode({
      rulePriority = 2
      description  = "Keep the most recent tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = var.tag_prefixes_to_keep
        countType     = "imageCountMoreThan"
        countNumber   = var.max_tagged_images
      }
      action = { type = "expire" }
    })
    : jsonencode({
      rulePriority = 2
      description  = "Keep the most recent tagged images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_tagged_images
      }
      action = { type = "expire" }
    })
  ] : []

  lifecycle_rules  = concat(local.untagged_rule, local.tagged_rule)
  lifecycle_policy = format("{\"rules\":[%s]}", join(",", local.lifecycle_rules))
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.kms_key_arn == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = length(local.lifecycle_rules) > 0 ? 1 : 0

  repository = aws_ecr_repository.this.name
  policy     = local.lifecycle_policy
}

resource "aws_ecr_repository_policy" "this" {
  count = var.attach_policy ? 1 : 0

  repository = aws_ecr_repository.this.name
  policy     = var.policy_json
}
