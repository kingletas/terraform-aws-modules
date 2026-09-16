# ansible-inventory

Publishes what Ansible needs to configure the infrastructure Terraform just built: a dynamic inventory that discovers hosts by tag, the facts they need, and the group variables that go with them.

## Usage

```hcl
module "ansible" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ansible-inventory?ref=v0.3.0"

  name       = "storefront-production"
  output_dir = "${path.module}/ansible"
  regions    = ["us-east-1"]

  discovery_tags = {
    Project     = "storefront"
    Environment = "production"
  }

  connection = "ssm"

  facts = {
    db_host     = module.database.endpoint
    redis_host  = module.cache.primary_endpoint_address
    search_host = module.search.endpoint
  }

  group_vars = {
    cron = { run_cron = "true" }
    web  = { run_cron = "false" }
  }
}
```

```bash
ansible-playbook -i ansible/aws_ec2.yml site.yml
```

## The inventory is a rule, not a list

**A generated host list cannot describe an autoscaling group.** Those instances do not exist when Terraform plans, so any list written at apply time is wrong the moment the group scales, and wrong again after an instance refresh replaces every member.

So the module writes the `amazon.aws.aws_ec2` plugin's configuration instead:

```yaml
plugin: amazon.aws.aws_ec2
filters:
  instance-state-name: [running]
  tag:Project: [storefront]
  tag:Environment: [production]
hostnames: [instance-id]
keyed_groups:
  - key: tags.Role
  - key: placement.availability_zone
    prefix: az
```

Ansible resolves that at run time. **A host joins the inventory by running and carrying the tags.** Nothing has to be re-applied, and a new role appears as a new group without this file changing. Groups come from the tag named in `group_by_tag`, which defaults to `Role`.

The file holds no addresses and no state, so it belongs in git rather than in a gitignore.

## Facts go to Parameter Store, not to disk

A file written by `terraform apply` exists only on the machine that ran it. Two operators produce two copies that disagree, and a CI runner's vanishes with the container.

`facts` is written to one SSM parameter instead. Every operator, every playbook and every instance reads the same value, and a stale local copy cannot exist. The generated `group_vars/all.yml` carries a `terraform_facts` lookup pointing at it, alongside any `all` variables you pass in `group_vars`, so a playbook needs no path passed in. The lookup reads the parameter from the first region in `regions`.

**Put ARNs in the facts, not secrets.** The consumer reads the secret at run time through its own IAM identity, which is what keeps the value out of both Terraform state and the parameter.

## Connecting over Systems Manager

`connection = "ssm"` reaches an instance with no public address, no open port 22 and no key to distribute. It needs the SSM agent on the instance, the `session-manager-plugin` on the runner, and the `ssm`, `ssmmessages` and `ec2messages` VPC endpoints if the subnet has no route out.

That removes the need for a bastion host, and with it a host to patch, a key to rotate and an address to allow-list.

`connection = "ssh"` is there for an AMI without the agent. `ssh_proxy_command` is exported for a person who wants a shell rather than a playbook.

## Notes

- **`discovery_tags` must not be empty**, because an inventory with no filter matches every running instance in the account.
- Hosts are named by instance ID. Instances in an autoscaling group share a `Name` tag, and naming hosts by it would collapse them into one.
- Over SSM, set `ssm_bucket_name`. The connection plugin moves every module it runs through that S3 bucket, not only copied files, so the instance role and the runner both need access to it.
- Instances are also grouped by availability zone as `az_*`, which is what a rolling play uses to avoid taking a whole zone at once.
- The module uses the AWS provider only to write the facts parameter. With `facts` empty it creates nothing in AWS, and `group_vars` may not set `terraform_facts` in the `all` group because the module writes that key.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |
| local | >= 2.4, < 3.0 |

### Providers

| Name | Version |
| ---- | ------- |
| local | >= 2.4, < 3.0 |
| aws | >= 6.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_ssm_parameter.facts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [local_file.group_vars](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.inventory](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix. Also the SSM parameter path the facts are written under. | `string` | n/a | yes |
| output\_dir | Directory the inventory configuration is written to. It must already exist, and the files in it are safe to commit. | `string` | n/a | yes |
| discovery\_tags | Tags identifying the hosts this inventory covers, such as<br/>{ Project = "storefront", Environment = "production" }.<br/><br/>Ansible discovers hosts by these tags at run time. Nothing here names an<br/>instance, which is what lets the inventory describe an autoscaling group. | `map(string)` | n/a | yes |
| regions | Regions to discover hosts in. | `list(string)` | n/a | yes |
| group\_by\_tag | Tag whose value becomes the Ansible group. Role is the usual choice, and instance-fleet sets it. | `string` | `"Role"` | no |
| ssh\_user | Default remote user, which varies by AMI family: ubuntu, ec2-user, admin, rocky. | `string` | `"ubuntu"` | no |
| connection | How Ansible reaches a host.<br/><br/>`ssm` tunnels through Systems Manager: no bastion, no open port 22, no key<br/>to distribute, and it works for a host with no public address. It needs the<br/>SSM agent on the instance and the session-manager-plugin on the runner.<br/><br/>`ssh` connects directly, for an AMI without the agent. | `string` | `"ssm"` | no |
| ssm\_bucket\_name | S3 bucket the SSM connection transfers files through. The aws\_ssm connection plugin moves every module it runs through this bucket, not only copied files, so a playbook over SSM needs it. The instance role and the runner both need access to it. | `string` | `null` | no |
| facts | Values every host should know: endpoints, bucket names and secret ARNs.<br/><br/>Written to SSM Parameter Store rather than to a file, so every operator and<br/>every CI runner reads the same values, and a stale local copy cannot exist. | `map(string)` | `{}` | no |
| group\_vars | Variables per Ansible group, keyed by group name. Written as group\_vars files, which are configuration rather than state and belong in git. With facts set, group\_vars/all.yml also carries the terraform\_facts lookup. | `map(map(string))` | `{}` | no |
| facts\_parameter\_tier | SSM parameter tier. Advanced raises the value limit to 8 KB and is billed monthly per parameter. | `string` | `"Standard"` | no |
| kms\_key\_arn | KMS key encrypting the facts. Null uses the AWS-managed SSM key. | `string` | `null` | no |
| tags | Tags applied to the SSM parameters. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| inventory\_path | Path of the generated dynamic inventory configuration. It holds no addresses, so it is safe to commit. |
| facts\_parameter\_name | SSM parameter holding the facts, or null when none were supplied. |
| facts\_parameter\_arn | ARN of the facts parameter, for the IAM policy that lets a host or a runner read it. |
| group\_var\_paths | Generated group\_vars files, keyed by group name. |
| discovery\_tags | Tags a host must carry to appear in this inventory. An instance without them is invisible to it. |
| ansible\_command | What to run to apply a playbook against the discovered hosts. |
| ssh\_proxy\_command | ProxyCommand for reaching an instance over Systems Manager, for a person rather than a playbook. Null when the connection is plain ssh. |
<!-- END_TF_DOCS -->
