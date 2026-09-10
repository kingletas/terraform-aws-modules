# backup-plan

A backup vault and plan, selecting resources by tag so new ones are picked up without an edit.

## Usage

```hcl
module "backups" {
  source = "github.com/kingletas/terraform-aws-modules//modules/backup-plan?ref=v0.1.0"

  name = "platform-daily"

  rules = {
    daily = {
      schedule          = "cron(0 5 * * ? *)"
      delete_after_days = 35
    }
    weekly = {
      schedule                = "cron(0 5 ? * SUN *)"
      cold_storage_after_days = 30
      delete_after_days       = 365
    }
  }

  selection_tags = {
    backed_up = { key = "Backup", value = "true" }
  }

  notifications = {
    sns_topic_arn = module.alerts.arn
  }
}
```

## Select by tag

Naming resource ARNs means every new database is unprotected until somebody remembers to add it. A tag condition picks up anything tagged from the moment it exists, which is the failure mode worth designing out.

## Notes

- **Notifications default to failures only.** A message on every successful nightly backup trains people to filter the whole channel, and the failure goes with it.
- `cold_storage_after_days` must be at least 90 days before `delete_after_days`, and a recovery point in cold storage takes hours to restore.
- **Vault Lock in compliance mode cannot be undone by anyone, including the account root, once `changeable_for_days` elapses.** It is the right control for a legal retention requirement and a permanent mistake anywhere else. Read the AWS documentation before setting it.
- Backup does not test restores. A plan that has never been restored from is a hypothesis.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |

### Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_backup_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_notifications.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_notifications) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.restore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the plan, the vault and the role. | `string` | n/a | yes |
| vault\_kms\_key\_arn | KMS key encrypting the vault. Null uses the AWS-managed Backup key. | `string` | `null` | no |
| vault\_lock | Vault Lock in compliance mode, which makes recovery points undeletable by anyone including root. Read the note in the README before turning this on. | <pre>object({<br/>    changeable_for_days = optional(number, 3)<br/>    min_retention_days  = optional(number, 7)<br/>    max_retention_days  = optional(number)<br/>  })</pre> | `null` | no |
| rules | Backup rules keyed by rule name. The schedule is a cron expression in UTC. | <pre>map(object({<br/>    schedule                  = string<br/>    start_window_minutes      = optional(number, 60)<br/>    completion_window_minutes = optional(number, 480)<br/>    delete_after_days         = optional(number, 35)<br/>    cold_storage_after_days   = optional(number)<br/>    enable_continuous_backup  = optional(bool, false)<br/>    recovery_point_tags       = optional(map(string), {})<br/><br/>    copy_to_vault_arn      = optional(string)<br/>    copy_delete_after_days = optional(number)<br/>  }))</pre> | n/a | yes |
| selection\_tags | Tag conditions selecting which resources are backed up, keyed by a stable name. Tag-based selection picks up new resources on its own. | <pre>map(object({<br/>    key   = string<br/>    value = string<br/>    type  = optional(string, "STRINGEQUALS")<br/>  }))</pre> | `{}` | no |
| selection\_resource\_arns | Resource ARNs to back up explicitly, in addition to anything the tags select. | `list(string)` | `[]` | no |
| not\_resources | Resource ARNs to exclude even when a tag selects them. | `list(string)` | `[]` | no |
| notifications | Where to send job events. The default set is failures only, because a message on every success is noise. | <pre>object({<br/>    sns_topic_arn = string<br/>    events        = optional(list(string), ["BACKUP_JOB_FAILED", "COPY_JOB_FAILED", "RESTORE_JOB_FAILED"])<br/>  })</pre> | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| plan\_id | ID of the backup plan. |
| plan\_arn | ARN of the backup plan. |
| vault\_name | Name of the backup vault. |
| vault\_arn | ARN of the backup vault, which a cross-region copy target references. |
| role\_arn | ARN of the role Backup assumes to take and restore backups. |
| selection\_id | ID of the resource selection, or null when nothing was selected. |
<!-- END_TF_DOCS -->
