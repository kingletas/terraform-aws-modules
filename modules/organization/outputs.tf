output "id" {
  description = "Identifier of the organization."
  value       = var.create_organization ? aws_organizations_organization.this[0].id : data.aws_organizations_organization.existing[0].id
}

output "arn" {
  description = "ARN of the organization."
  value       = var.create_organization ? aws_organizations_organization.this[0].arn : data.aws_organizations_organization.existing[0].arn
}

output "root_id" {
  description = "Identifier of the root, which is what a policy attaches to when it should apply everywhere."
  value       = local.root_id
}

output "management_account_id" {
  description = "Account the organization is managed from. Nothing should be deployed into it."
  value       = var.create_organization ? aws_organizations_organization.this[0].master_account_id : data.aws_organizations_organization.existing[0].master_account_id
}

output "organizational_unit_ids" {
  description = "Organizational unit IDs keyed the way they were declared, a child as parent/child. This is what a policy module attaches to."
  value       = local.unit_ids
}

output "organizational_unit_arns" {
  description = "Organizational unit ARNs, keyed the same way."
  value = merge(
    { for key, unit in aws_organizations_organizational_unit.top : key => unit.arn },
    { for key, unit in aws_organizations_organizational_unit.nested : key => unit.arn },
  )
}

output "account_ids" {
  description = "Account IDs keyed by the name they were declared under."
  value       = { for key, account in aws_organizations_account.this : key => account.id }
}

output "account_arns" {
  description = "Account ARNs keyed by the name they were declared under."
  value       = { for key, account in aws_organizations_account.this : key => account.arn }
}

output "account_role_arns" {
  description = "ARN of the role to assume in each member account from the management account."
  value = {
    for key, account in aws_organizations_account.this :
    key => format("arn:%s:iam::%s:role/%s", data.aws_partition.current.partition, account.id, var.accounts[key].role_name)
  }
}
