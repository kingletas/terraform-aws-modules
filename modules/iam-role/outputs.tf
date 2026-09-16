output "arn" {
  description = "ARN of the role, available only once its policies are attached so a consumer never assumes it half-granted."
  value       = aws_iam_role.this.arn

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy.this,
  ]
}

output "name" {
  description = "Generated name of the role, available only once its policies are attached."
  value       = aws_iam_role.this.name

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy.this,
  ]
}

output "id" {
  description = "ID of the role, which is the same as its name, available only once its policies are attached."
  value       = aws_iam_role.this.id

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy.this,
  ]
}

output "unique_id" {
  description = "Stable unique ID, which does not change if the role is renamed, available only once its policies are attached."
  value       = aws_iam_role.this.unique_id

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy.this,
  ]
}

output "instance_profile_name" {
  description = "Instance profile name, or null when none was created, available only once the role's policies are attached."
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy.this,
  ]
}

output "instance_profile_arn" {
  description = "Instance profile ARN, or null when none was created, available only once the role's policies are attached."
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : null

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy.this,
  ]
}
