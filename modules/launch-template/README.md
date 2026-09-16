# launch-template

A launch template describing how an instance is built, for an autoscaling group or a spot fleet to use.

## Usage

```hcl
module "app_template" {
  source = "github.com/kingletas/terraform-aws-modules//modules/launch-template?ref=v0.4.0"

  name          = "platform-app"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "m7g.large"

  security_group_ids       = [module.app_sg.id]
  iam_instance_profile_arn = module.app_role.instance_profile_arn

  user_data = file("${path.module}/cloud-init.yaml")

  root_volume = { size = 50 }
}
```

## What is fixed rather than configurable

- **IMDSv2 is required**, with a hop limit of 1. Token-less metadata is what a server-side request forgery bug reaches to steal role credentials, and a hop limit above 1 hands it to containers on the instance too.
- **Every volume is encrypted**, root and extra.

## Notes

- **The root device name is read from the AMI**, because it differs between image families (`/dev/xvda` on Amazon Linux, `/dev/sda1` on Ubuntu) and a wrong name adds a second disk instead of configuring the root. Set `root_volume.device_name` to override it, and the module then skips the lookup. Without it, the identity running Terraform must be able to describe the image.
- **An `image_id` of `resolve:ssm:/aws/service/...` is resolved by EC2 at launch**, so there is no image to look up at plan. It needs `root_volume.device_name`.
- `user_data` is passed unencoded; the module base64-encodes it.
- Setting `instance_requirements` lets AWS pick any instance type that fits, which is how you get spot capacity from a wide pool. It replaces `instance_type`. The instance architecture follows the AMI, so choose an arm64 image for Graviton types.
- `instance_metadata_tags` is off by default. Turn it on to read tags from the metadata service; AWS then refuses tag keys containing anything other than letters, digits and `+ - = . , _ : @`, and the plan checks this.
- The template is created with `name_prefix` and `create_before_destroy`, so a change that forces replacement does not collide with the existing name.

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
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the launch template. | `string` | n/a | yes |
| description | What instances from this template are for. | `string` | `null` | no |
| image\_id | AMI to launch, or a resolve:ssm: parameter reference that EC2 resolves at launch. Resolve an AMI from a data source in the caller so the template never pins a stale image. | `string` | n/a | yes |
| instance\_type | Default instance type. An autoscaling group with a mixed instances policy overrides this. | `string` | `"t3.small"` | no |
| key\_name | EC2 key pair for SSH. Prefer Session Manager and leave this null. | `string` | `null` | no |
| security\_group\_ids | Security groups applied to the primary network interface. | `list(string)` | `[]` | no |
| iam\_instance\_profile\_arn | IAM instance profile ARN. Needed for Session Manager and for anything calling AWS APIs. | `string` | `null` | no |
| user\_data | Cloud-init user data, unencoded. The module base64-encodes it. | `string` | `null` | no |
| associate\_public\_ip\_address | Give instances a public IP. Off by default. | `bool` | `false` | no |
| root\_volume | Root volume settings. Always encrypted. device\_name defaults to the AMI's own root device, which is /dev/xvda on Amazon Linux and /dev/sda1 on Ubuntu; a wrong name adds a second disk instead of configuring the root. Required when image\_id is a resolve:ssm: reference. | <pre>object({<br/>    device_name           = optional(string)<br/>    type                  = optional(string, "gp3")<br/>    size                  = optional(number, 20)<br/>    iops                  = optional(number)<br/>    throughput            = optional(number)<br/>    delete_on_termination = optional(bool, true)<br/>  })</pre> | `{}` | no |
| extra\_volumes | Additional block devices keyed by a stable name. | <pre>map(object({<br/>    device_name           = string<br/>    size                  = number<br/>    type                  = optional(string, "gp3")<br/>    iops                  = optional(number)<br/>    throughput            = optional(number)<br/>    delete_on_termination = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| kms\_key\_id | KMS key for EBS encryption. Null uses the AWS-managed EBS key. | `string` | `null` | no |
| detailed\_monitoring | Enable one-minute CloudWatch monitoring. | `bool` | `true` | no |
| instance\_requirements | Attribute-based instance selection, letting AWS pick any type that fits. Replaces instance\_type when set. The architecture follows the AMI. | <pre>object({<br/>    vcpu_min       = number<br/>    vcpu_max       = number<br/>    memory_mib_min = number<br/>    memory_mib_max = number<br/>  })</pre> | `null` | no |
| capacity\_reservation\_preference | Whether instances may use an open capacity reservation. | `string` | `"open"` | no |
| instance\_metadata\_tags | Expose instance tags through the metadata service. AWS then refuses any tag key outside letters, digits and + - = . , \_ : @, which rules out spaces and slashes. | `bool` | `false` | no |
| tags | Tags applied to the template and to instances and volumes launched from it. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the launch template. |
| arn | ARN of the launch template. |
| name | Generated name of the launch template. |
| latest\_version | Newest version number. An autoscaling group pointed at this follows every change. |
<!-- END_TF_DOCS -->
