# Application instances in a private VPC

Two instances in private subnets, reachable through Systems Manager Session Manager, with no SSH key and nothing open inbound from the internet.

This is the shape most application tiers want: instances that can reach out, that nothing can reach in to, and that you can still get a shell on.

## What it builds

- A VPC across two availability zones with a single shared NAT gateway.
- A security group allowing HTTP from inside the VPC and instances to talk to each other.
- An IAM role and instance profile carrying `AmazonSSMManagedInstanceCore`.
- Two Amazon Linux 2023 instances running nginx, installed by cloud-init.

## Running it

```bash
terraform init && terraform apply
```

The AMI is resolved at plan time from the latest Amazon Linux 2023 image, so nothing is pinned to a stale identifier.

## Getting a shell

Session Manager needs no key, no bastion and no inbound rule:

```bash
aws ssm start-session --target "$(terraform output -json instance_ids | jq -r 'to_entries[0].value')"
```

If the session times out, the instance has not registered yet. Registration needs outbound internet through the NAT gateway and takes a minute or two after boot.

## What it costs

The NAT gateway is the expensive part, billed hourly plus per gigabyte. This example sets `single_nat_gateway = true` to keep that to one. In production you would usually want one per zone, so a zone failure does not take outbound traffic down everywhere.

## Cleaning up

```bash
terraform destroy
```
