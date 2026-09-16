# instance-fleet

A set of EC2 instances in named roles, each a variation on one base specification.

Where `ec2-instance` runs N identical instances, this runs a **fleet**: web nodes, a cron node, an admin node, a bastion, a builder. All come from one AMI and one security posture, and differ only where they genuinely differ.

## Usage

```hcl
module "fleet" {
  source = "github.com/kingletas/terraform-aws-modules//modules/instance-fleet?ref=v0.3.0"

  name = "storefront-production"

  defaults = {
    ami_id               = data.aws_ami.base.id
    instance_type        = "c7g.xlarge"
    subnet_ids           = values(module.vpc.private_subnet_ids)
    security_group_ids   = [module.node_sg.id]
    iam_instance_profile = module.node_role.instance_profile_name
    kms_key_id           = module.kms.arn
    root_volume_size     = 60
    user_data            = local.cloud_init
  }

  roles = {
    web = { count = 6 }

    cron = { count = 1, root_volume_size = 100 }

    bastion = {
      count                       = 1
      instance_type               = "t3.micro"
      subnet_ids                  = values(module.vpc.public_subnet_ids)
      associate_public_ip_address = true
      assign_elastic_ip           = true
    }

    builder = {
      count            = 1
      instance_type    = "c7g.2xlarge"
      root_volume_size = 200

      extra_volumes = {
        workspace = { device_name = "/dev/sdf", size = 200, throughput = 500 }
      }
    }
  }

  tags = module.context.tags
}
```

## Inheritance is what makes this readable

A role names only what differs. The bastion above states five things. Everything else (AMI, security groups, instance profile, encryption, IMDSv2) comes from `defaults` and stays consistent across the fleet by construction.

## Every role is numbered

Instances are named `prefix-role-01` and upward, including a role with exactly one member.

**A rename in Terraform is a destroy and a create.** If a single-instance role kept a bare name, adding the second instance would rename the first, replacing a running node to make room for a new one, which is never what anybody meant by "scale up".

`numbered = false` exists for the case where something outside Terraform depends on the bare name: a DNS record, a monitoring check, a firewall rule another team wrote. It is an escape hatch, not a style choice, and it takes the rename risk back on.

## Notes

- **Instances are spread round-robin** across the role's subnet list, so a role of three lands in three zones without arithmetic in the caller.
- **`assign_elastic_ip`** gives a role a stable public address that survives replacement, which is what a firewall rule elsewhere names.
- **A replacement is destroy-first**, because an extra volume can be attached to one instance at a time: the old instance is stopped and destroyed, then the new one is built and given the same volumes. Expect a short gap while a node is replaced.
- **Extra volumes outlive their instance.** Each takes its availability zone from the instance's subnet, so it survives a replacement, and it is never deleted with the instance. A volume is deleted only when you remove it from the role or remove its instance.
- Every root and extra volume is **encrypted**, and **IMDSv2 is required** with a hop limit of 1.
- `instance_metadata_tags` is off by default. Turn it on to read tags from the metadata service; AWS then refuses tag keys containing anything other than letters, digits and `+ - = . , _ : @`, and the plan checks every key a role would carry, including the keys in the provider's `default_tags`.
- `count = 0` removes a role cleanly, which is how a feature flag turns a whole tier off.
- Outputs are grouped by role as well as by name (`by_role`, `private_ips_by_role`, `instance_ids_by_role`), because a downstream inventory, an SSM run command and a load balancer attachment all address a tier rather than a host.

## What this is not

**This is a fleet of pets.** Instances are not replaced on a schedule, do not autoscale and do not recover from a zone failure on their own. Where a tier is stateless and should scale, use `launch-template` with `autoscaling-group` instead.

The two combine well: an autoscaling web tier beside a handful of named nodes that do jobs exactly one machine may do.

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
| [aws_eip.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_volume_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the fleet. Every instance is named prefix-role or prefix-role-NN. | `string` | n/a | yes |
| defaults | Base specification every role starts from. A role overrides only what differs, which is what stops each one being a copy of the others. | <pre>object({<br/>    ami_id        = string<br/>    instance_type = optional(string, "t3.medium")<br/><br/>    subnet_ids           = list(string)<br/>    security_group_ids   = optional(list(string), [])<br/>    key_name             = optional(string)<br/>    iam_instance_profile = optional(string)<br/><br/>    associate_public_ip_address = optional(bool, false)<br/>    ebs_optimized               = optional(bool, true)<br/>    monitoring                  = optional(bool, true)<br/>    source_dest_check           = optional(bool, true)<br/><br/>    root_volume_type       = optional(string, "gp3")<br/>    root_volume_size       = optional(number, 30)<br/>    root_volume_iops       = optional(number)<br/>    root_volume_throughput = optional(number)<br/><br/>    kms_key_id = optional(string)<br/>    user_data  = optional(string)<br/>  })</pre> | n/a | yes |
| roles | Roles in the fleet, keyed by role name. Each inherits from `defaults` and<br/>overrides only what differs.<br/><br/>Instances are named `prefix-role-01` and upward. Numbering is on by default<br/>because a rename in Terraform destroys and recreates: without it, adding a<br/>second instance to a role replaces the first.<br/><br/>Set `numbered = false` only for a role that will never have a second member<br/>and whose bare name something outside Terraform depends on. | <pre>map(object({<br/>    count = optional(number, 1)<br/><br/>    instance_type        = optional(string)<br/>    subnet_ids           = optional(list(string))<br/>    security_group_ids   = optional(list(string))<br/>    key_name             = optional(string)<br/>    iam_instance_profile = optional(string)<br/>    ami_id               = optional(string)<br/><br/>    associate_public_ip_address = optional(bool)<br/>    assign_elastic_ip           = optional(bool, false)<br/>    source_dest_check           = optional(bool)<br/>    monitoring                  = optional(bool)<br/>    ebs_optimized               = optional(bool)<br/><br/>    root_volume_type       = optional(string)<br/>    root_volume_size       = optional(number)<br/>    root_volume_iops       = optional(number)<br/>    root_volume_throughput = optional(number)<br/><br/>    kms_key_id = optional(string)<br/>    user_data  = optional(string)<br/><br/>    extra_volumes = optional(map(object({<br/>      device_name = string<br/>      size        = number<br/>      type        = optional(string, "gp3")<br/>      iops        = optional(number)<br/>      throughput  = optional(number)<br/>    })), {})<br/><br/>    # Numbered by default, because a rename in Terraform is a destroy and a<br/>    # create. Turn it off only for a role that will never have a second member.<br/>    numbered = optional(bool, true)<br/><br/>    tags = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| instance\_metadata\_tags | Expose instance tags through the metadata service. AWS then refuses any tag key outside letters, digits and + - = . , \_ : @, which rules out spaces and slashes. | `bool` | `false` | no |
| tags | Tags applied to every instance, merged under each role's own tags. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| instances | Every instance, keyed by name, with the fields a downstream inventory or ssh config needs. |
| by\_role | Instance names grouped by role, so a caller can address a whole tier without filtering. |
| private\_ips\_by\_role | Private addresses grouped by role. |
| instance\_ids | Instance IDs, keyed by name. |
| instance\_ids\_by\_role | Instance IDs grouped by role, which is what an SSM run command targets. |
| elastic\_ips | Elastic IPs, keyed by instance name. Empty for roles that did not ask for one. |
| roles | Role names in the fleet. |
<!-- END_TF_DOCS -->
