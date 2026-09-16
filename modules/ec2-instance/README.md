# ec2-instance

A set of identically configured EC2 instances, spread round-robin across the subnets you give it.

Instances are named `name-01`, `name-02` and so on, and every output is keyed by that name rather than by list position. Removing an instance therefore does not renumber the ones that remain.

## Usage

```hcl
module "app" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ec2-instance?ref=v0.3.1"

  name           = "platform-app"
  instance_count = 3
  instance_type  = "t3.medium"
  ami_id         = data.aws_ami.amazon_linux.id
  subnet_ids     = values(module.vpc.private_subnet_ids)

  security_group_ids   = [module.app_sg.id]
  iam_instance_profile = aws_iam_instance_profile.app.name

  root_volume = {
    type = "gp3"
    size = 50
  }

  tags = {
    Environment = "production"
  }
}
```

## What is fixed rather than configurable

Three things are not options, because turning them off is a defect rather than a trade-off:

- **IMDSv2 is required.** Token-less instance metadata is what a server-side request forgery bug reaches to steal role credentials. The hop limit is 1, so a container on the instance cannot reach it either.
- **Every volume is encrypted**, root and extra. `kms_key_id` chooses the key; leaving it null uses the AWS-managed EBS key.
- **A replacement is destroy-first.** An extra volume can be attached to one instance at a time, so the old instance is stopped, its volumes detached and the instance destroyed before the new one is built and the same volumes attached to it. Expect a short gap while the instance is replaced.

## Extra volumes

`extra_volumes` attaches the same set of volumes to every instance. Each volume takes its availability zone from the instance's subnet, not from the instance, so it survives a replacement and is attached to the new instance. The volumes are never deleted with an instance; one is deleted only when you remove it from `extra_volumes` or remove its instance by lowering `instance_count`. Detaching stops the instance first, because detaching a mounted volume hangs.

```hcl
extra_volumes = {
  data = {
    device_name = "/dev/sdf"
    size        = 200
    type        = "gp3"
    throughput  = 250
  }
}
```

Formatting and mounting the volume is the caller's job, in `user_data`.

## Reaching the instances

The module has no SSH provisioner, so Terraform needs no network path to the instances to finish an apply.

Use cloud-init through `user_data` for anything that must happen at first boot, and Systems Manager Session Manager to get a shell. Session Manager needs `AmazonSSMManagedInstanceCore` on the instance profile and nothing inbound at all. See `examples/ec2-in-vpc`.

## Notes

- `user_data_replace_on_change` is on. Changing user data replaces the instance, rather than leaving one running that no longer matches its own configuration.
- `instance_metadata_tags` is off by default. Turn it on to read the instance's tags from the metadata service. AWS then refuses tag keys containing anything other than letters, digits and `+ - = . , _ : @` (so no spaces or slashes), and the plan checks this, including the keys in the provider's `default_tags`.
- `iops` and `throughput` are ignored for volume types that do not accept them, so you can leave them set while switching type.

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
| [aws_ebs_volume.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_volume_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix. Instances are named name-01, name-02 and so on. | `string` | n/a | yes |
| instance\_count | How many instances to launch. | `number` | `1` | no |
| ami\_id | AMI to launch. Resolve this from a data source in the caller so the module never pins an image. | `string` | n/a | yes |
| instance\_type | EC2 instance type. | `string` | `"t3.small"` | no |
| subnet\_ids | Subnets to spread instances across, round-robin. | `list(string)` | n/a | yes |
| security\_group\_ids | Security groups attached to every instance. | `list(string)` | `[]` | no |
| key\_name | Existing EC2 key pair for SSH access. Prefer Systems Manager Session Manager and leave this null. | `string` | `null` | no |
| iam\_instance\_profile | IAM instance profile name. Required for Session Manager access. | `string` | `null` | no |
| user\_data | Cloud-init user data. Rendered by the caller, so the module holds no scripts. | `string` | `null` | no |
| user\_data\_replace\_on\_change | Replace the instance when user data changes, rather than leaving a running instance that no longer matches its configuration. | `bool` | `true` | no |
| associate\_public\_ip\_address | Give each instance a public IP. Off by default; reach private instances through a NAT gateway or Session Manager. | `bool` | `false` | no |
| ebs\_optimized | Enable EBS optimization. | `bool` | `true` | no |
| monitoring | Enable detailed CloudWatch monitoring at one-minute resolution. | `bool` | `true` | no |
| root\_volume | Root EBS volume settings. Always encrypted. | <pre>object({<br/>    type                  = optional(string, "gp3")<br/>    size                  = optional(number, 20)<br/>    iops                  = optional(number)<br/>    throughput            = optional(number)<br/>    delete_on_termination = optional(bool, true)<br/>  })</pre> | `{}` | no |
| extra\_volumes | Additional EBS volumes attached to every instance, keyed by a stable name. They are separate volumes, so they outlive the instance and are never deleted with it. | <pre>map(object({<br/>    device_name = string<br/>    size        = number<br/>    type        = optional(string, "gp3")<br/>    iops        = optional(number)<br/>    throughput  = optional(number)<br/>  }))</pre> | `{}` | no |
| kms\_key\_id | KMS key for EBS encryption. Defaults to the AWS-managed EBS key. | `string` | `null` | no |
| instance\_metadata\_tags | Expose instance tags through the metadata service. AWS then refuses any tag key outside letters, digits and + - = . , \_ : @, which rules out spaces and slashes. | `bool` | `false` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| instance\_ids | Instance IDs, keyed by instance name. |
| instance\_arns | Instance ARNs, keyed by instance name. |
| private\_ips | Private IPv4 addresses, keyed by instance name. |
| public\_ips | Public IPv4 addresses, keyed by instance name. Empty unless public IPs were requested. |
| availability\_zones | Availability zone each instance landed in, keyed by instance name. |
| volume\_ids | Additional EBS volume IDs, keyed by instance name and volume name. |
<!-- END_TF_DOCS -->
