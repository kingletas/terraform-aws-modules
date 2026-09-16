# efs-filesystem

A shared POSIX file system, with mount targets in the subnets you name and a file system policy that allows mounting only through those mount targets and requires TLS.

## Usage

```hcl
module "shared" {
  source = "github.com/kingletas/terraform-aws-modules//modules/efs-filesystem?ref=v0.4.0"

  name               = "platform-shared"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.id]

  access_points = {
    uploads = {
      path      = "/uploads"
      posix_uid = 1000
      posix_gid = 1000
    }
  }
}
```

## Mount targets are per availability zone

A client can only mount from a zone that has a mount target. Give this module one subnet per zone your workload runs in, or a task that lands in the wrong zone fails to mount with a timeout rather than a clear error.

Mount targets are billed by the hour, so this is a real cost decision as well as an availability one.

## Notes

- **Root on a client is squashed by default.** With `allow_client_root_access` off, a client acting as root is treated as an unprivileged user, so it cannot change ownership or read files it does not own. An access point's POSIX identity still applies. Turn it on only for a client that needs root on the file system.
- The security group on the mount targets needs NFS, TCP 2049, from the clients.
- An access point pins a directory and a POSIX identity, so a client cannot read outside its own path even if it asks.
- `throughput_mode` defaults to `elastic`, which bills for what you use. `bursting` scales with how much you have stored, which surprises people on a small but busy file system.

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
| [aws_efs_access_point.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_backup_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_backup_policy) | resource |
| [aws_efs_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_file_system_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system_policy) | resource |
| [aws_efs_mount_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the file system and the resources around it. | `string` | n/a | yes |
| subnet\_ids | Subnets to create mount targets in, keyed by availability zone. A client can only mount from a zone that has one. The vpc module's private\_subnet\_ids output has this shape. | `map(string)` | n/a | yes |
| security\_group\_ids | Security groups on the mount targets. They need NFS, TCP 2049, from the clients. | `list(string)` | `[]` | no |
| performance\_mode | generalPurpose has the lowest latency. maxIO scales further and cannot be changed later. | `string` | `"generalPurpose"` | no |
| throughput\_mode | elastic bills for what you use. provisioned buys a fixed rate. bursting scales with stored size. | `string` | `"elastic"` | no |
| provisioned\_throughput\_in\_mibps | Throughput to buy, in MiB/s. Only used when throughput\_mode is provisioned. | `number` | `null` | no |
| kms\_key\_arn | KMS key for encryption at rest. Null uses the AWS-managed EFS key. | `string` | `null` | no |
| transition\_to\_ia\_days | Move a file to infrequent access after this long untouched. Null keeps everything in standard storage. | `string` | `"AFTER_30_DAYS"` | no |
| enable\_backup | Turn on the automatic daily backup EFS provides. | `bool` | `true` | no |
| allow\_client\_root\_access | Let a client act as root on the file system. Off, root on a client is squashed to an unprivileged user, and an access point's POSIX identity still works. | `bool` | `false` | no |
| access\_points | Access points keyed by a stable name. Each pins a directory and a POSIX identity, so a client cannot read outside its own path. | <pre>map(object({<br/>    path           = string<br/>    owner_uid      = optional(number, 1000)<br/>    owner_gid      = optional(number, 1000)<br/>    permissions    = optional(string, "0755")<br/>    posix_uid      = optional(number, 1000)<br/>    posix_gid      = optional(number, 1000)<br/>    secondary_gids = optional(list(number), [])<br/>  }))</pre> | `{}` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the file system, which is what a mount command names. |
| arn | ARN of the file system. |
| dns\_name | DNS name of the file system, resolvable from inside the VPC. |
| mount\_target\_ids | Mount target IDs, keyed by availability zone. |
| mount\_target\_ips | Mount target IP addresses, keyed by availability zone. |
| access\_point\_arns | Access point ARNs, keyed by the name you gave each one. |
<!-- END_TF_DOCS -->
