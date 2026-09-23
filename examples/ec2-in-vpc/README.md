# ec2-in-vpc

Two application instances in private subnets, reachable through Systems Manager Session Manager, with no SSH key and nothing open inbound from the internet. This is the shape most application tiers want: instances that can reach out, that nothing can reach in to, and that you can still get a shell on.

## What it builds

- A VPC across two availability zones with a single shared NAT gateway.
- A security group allowing HTTP from inside the VPC and instances in the group to reach each other.
- An IAM role and instance profile carrying `AmazonSSMManagedInstanceCore`.
- Two Amazon Linux 2023 instances with a 30 GiB gp3 root volume, running nginx installed by cloud-init.

The AMI is resolved at plan time from the latest Amazon Linux 2023 x86_64 image, so nothing is pinned to a stale identifier.

## Before you deploy

- AWS credentials for the target account, and Terraform 1.9 or later.
- The AWS CLI with the Session Manager plugin, and `jq`, to open a shell as shown below.

## How to use it

```bash
terraform init
terraform plan
terraform apply
```

To check the example without AWS credentials, run its plan test from the top of the repository. It plans against mock providers and creates nothing:

```bash
make test DIR=examples/ec2-in-vpc
```

The `.tf` files call modules by relative path (`../../modules/<name>`). If you copy this example outside this repository, change each `source` to `github.com/kingletas/terraform-aws-modules//modules/<name>?ref=v0.6.0`.

### Get a shell

Session Manager needs no key, no bastion and no inbound rule:

```bash
aws ssm start-session --target "$(terraform output -json instance_ids | jq -r 'to_entries[0].value')"
```

If the session times out, the instance has not registered yet. Registration needs outbound internet through the NAT gateway and takes a minute or two after boot.

### Clean up

```bash
terraform destroy
```

## Inputs worth knowing

| Variable | Default | What it changes |
|---|---|---|
| `region` | `us-east-1` | Region to deploy into |
| `name` | `app-demo` | Name prefix for everything created |
| `vpc_cidr` | `10.30.0.0/16` | VPC address range |
| `instance_count` | `2` | Number of application instances |
| `instance_type` | `t3.small` | EC2 instance type |

## Costs

The NAT gateway is the expensive part, billed hourly plus per gigabyte processed. This example sets `single_nat_gateway = true` to keep that to one.

## Limits

- One NAT gateway serves both zones, so a zone failure stops outbound traffic everywhere. Production usually wants one per zone.
- nginx listens on port 80 and is reachable from inside the VPC only. There is no load balancer and no TLS.
