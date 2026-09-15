locals {
  # A child is addressed as parent/child, so the keys of both maps are known at
  # plan and stay stable when a sibling is removed.
  nested_units = {
    for unit in flatten([
      for parent, settings in var.organizational_units : [
        for name, child in settings.children : {
          key    = format("%s/%s", parent, name)
          name   = name
          parent = parent
          tags   = child.tags
        }
      ]
    ]) : unit.key => unit
  }

  root_id = var.create_organization ? aws_organizations_organization.this[0].roots[0].id : data.aws_organizations_organization.existing[0].roots[0].id

  unit_ids = merge(
    { for key, unit in aws_organizations_organizational_unit.top : key => unit.id },
    { for key, unit in aws_organizations_organizational_unit.nested : key => unit.id },
  )

  # Known from the variables alone, so an account can be checked against it
  # before any organizational unit exists.
  unit_keys = concat(keys(var.organizational_units), keys(local.nested_units))
}

# Deleting this resource removes the organization and every member account is
# left standalone. It is not a thing to do by accident.
resource "aws_organizations_organization" "this" {
  count = var.create_organization ? 1 : 0

  feature_set                   = var.feature_set
  aws_service_access_principals = var.aws_service_access_principals
  enabled_policy_types          = var.enabled_policy_types

  lifecycle {
    precondition {
      condition     = var.feature_set == "ALL" || length(var.enabled_policy_types) == 0
      error_message = "Policy types need the ALL feature set. A consolidated billing organization cannot carry policies."
    }

    precondition {
      condition     = var.feature_set == "ALL" || length(var.aws_service_access_principals) == 0
      error_message = "Trusted service access needs the ALL feature set."
    }
  }
}

data "aws_organizations_organization" "existing" {
  count = var.create_organization ? 0 : 1
}

resource "aws_organizations_organizational_unit" "top" {
  for_each = var.organizational_units

  name      = each.key
  parent_id = local.root_id

  tags = merge(var.tags, each.value.tags, { Name = each.key })
}

resource "aws_organizations_organizational_unit" "nested" {
  for_each = local.nested_units

  name      = each.value.name
  parent_id = aws_organizations_organizational_unit.top[each.value.parent].id

  tags = merge(var.tags, each.value.tags, { Name = each.key })
}

# An account cannot be deleted. Removing it from the configuration either closes
# it or leaves it orphaned in the organization, which is why close_on_deletion
# defaults to false and the choice is per account.
resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name  = each.value.name
  email = each.value.email

  parent_id = each.value.parent == null ? local.root_id : lookup(local.unit_ids, each.value.parent, null)

  role_name                  = each.value.role_name
  iam_user_access_to_billing = each.value.iam_user_access_to_billing
  close_on_deletion          = each.value.close_on_deletion

  tags = merge(var.tags, each.value.tags, { Name = each.value.name })

  lifecycle {
    # Both are read only at creation. AWS ignores a later change and Terraform
    # would otherwise plan a replacement, which means closing the account.
    ignore_changes = [role_name, iam_user_access_to_billing]

    precondition {
      condition     = each.value.parent == null || contains(local.unit_keys, coalesce(each.value.parent, "-"))
      error_message = format("Account %s names the organizational unit %s, which is not in organizational_units.", each.key, coalesce(each.value.parent, "-"))
    }
  }
}
