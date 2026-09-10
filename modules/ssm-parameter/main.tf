resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name        = each.key
  value       = var.values[each.key]
  type        = each.value.type
  description = each.value.description

  tier            = each.value.tier
  data_type       = each.value.data_type
  allowed_pattern = each.value.allowed_pattern
  key_id          = each.value.type == "SecureString" ? var.kms_key_arn : null
  overwrite       = var.overwrite_existing

  tags = merge(var.tags, { Name = each.key })

  lifecycle {
    precondition {
      condition     = contains(keys(nonsensitive(var.values)), each.key)
      error_message = format("No value was given for parameter %s.", each.key)
    }
  }
}
