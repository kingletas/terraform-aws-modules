# vpc

A VPC with public and private subnets spread across the availability zones you name, plus the routing to make them useful.

One public and one private subnet are created per zone. Public subnets share a route table pointing at an internet gateway. Each private subnet gets its own route table, so you can route each zone through its own NAT gateway and keep a zone failure contained.

Flow logging is on by default, writing to a CloudWatch log group this module creates along with the IAM role it needs.

## Usage

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=v0.5.0"

  name               = "platform"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "production"
  }
}
```

## How subnets are addressed

Subnets are carved from `cidr_block` with `cidrsubnet(cidr_block, subnet_newbits, slot)`. `subnet_newbits` is how many bits are added to the VPC prefix, so a `/16` with the default `8` gives `/24` subnets, each with 251 usable addresses (AWS reserves five in every subnet).

A zone's position comes from the last letter of its name: `a` is 0, `b` is 1, and so on up to `h`, which is 7. Each tier owns eight slots. A zone's public subnet uses slot `position` and its private subnet uses slot `8 + position`. With the defaults you get:

| Zone | Public | Private |
|---|---|---|
| `us-east-1a` | `10.0.0.0/24` | `10.0.8.0/24` |
| `us-east-1b` | `10.0.1.0/24` | `10.0.9.0/24` |
| `us-east-1c` | `10.0.2.0/24` | `10.0.10.0/24` |

A zone's subnets depend only on its own position, so adding or removing another zone does not move them. The sixteen slots are why a VPC holds at most eight zones and why `subnet_newbits` must be at least 4. The VPC prefix plus `subnet_newbits` must also give subnets of `/28` or larger, the smallest subnet AWS allows.

A Local Zone can share its last letter with a regional zone, and a Wavelength Zone ends in a digit. Give either a position of its own, from 0 to 7, in `availability_zone_indexes`. The plan fails if two zones resolve to the same position.

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=v0.5.0"

  name                      = "platform"
  cidr_block                = "10.0.0.0/16"
  availability_zones        = ["us-west-2a", "us-west-2b", "us-west-2-lax-1a"]
  availability_zone_indexes = { "us-west-2-lax-1a" = 7 }
}
```

## What this costs

A NAT gateway is billed hourly per zone plus per gigabyte processed, and it is usually the largest line on a small VPC's bill. Three of them cost three times as much as one.

- `enable_nat_gateway = false` if nothing in a private subnet needs outbound internet.
- `single_nat_gateway = true` to share one, placed in the first zone in `availability_zones`, across every zone. Cheaper, and losing that zone takes outbound traffic down for all of them.

## Notes

- The VPC's default security group is adopted and emptied, so nothing inherits an open group by accident.
- `map_public_ip_on_launch` is off. Instances in a public subnet need an Elastic IP or an explicit `associate_public_ip_address`.
- `flow_log_retention_days = 0` turns flow logging off entirely, including the log group and IAM role.

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
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix applied to the VPC and everything inside it. | `string` | n/a | yes |
| cidr\_block | IPv4 CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |
| availability\_zones | Availability zones to spread subnets across, at most eight. One public and one private subnet are created per zone, placed by the zone's last letter (a is 0, h is 7) unless availability\_zone\_indexes names it. | `list(string)` | n/a | yes |
| availability\_zone\_indexes | Subnet position from 0 to 7 for a zone whose last letter does not place it, such as a Local Zone that shares a letter with a regional zone. Keyed by zone name. | `map(number)` | `{}` | no |
| subnet\_newbits | Bits added to the VPC prefix when carving subnets. At least 4, because each tier reserves eight subnet slots. A /16 with 8 newbits yields /24 subnets. | `number` | `8` | no |
| enable\_nat\_gateway | Give private subnets outbound internet access through a NAT gateway. | `bool` | `true` | no |
| single\_nat\_gateway | Route every private subnet through one NAT gateway instead of one per zone. Cheaper, and a single point of failure. | `bool` | `false` | no |
| map\_public\_ip\_on\_launch | Assign a public IP to instances launched into a public subnet. Off by default; attach an Elastic IP or use a NAT gateway instead. | `bool` | `false` | no |
| flow\_log\_retention\_days | Days to retain VPC flow logs. Set to 0 to disable flow logging entirely. | `number` | `365` | no |
| flow\_log\_kms\_key\_arn | KMS key used to encrypt the flow log group. Defaults to the CloudWatch Logs service key. | `string` | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| vpc\_id | ID of the VPC. |
| vpc\_arn | ARN of the VPC. |
| cidr\_block | IPv4 CIDR block of the VPC. |
| public\_subnet\_ids | Public subnet IDs, keyed by availability zone. |
| private\_subnet\_ids | Private subnet IDs, keyed by availability zone. |
| public\_subnet\_cidrs | Public subnet CIDR blocks, keyed by availability zone. |
| private\_subnet\_cidrs | Private subnet CIDR blocks, keyed by availability zone. |
| internet\_gateway\_id | ID of the internet gateway. |
| nat\_gateway\_ids | NAT gateway IDs, keyed by availability zone. Empty when NAT is disabled. |
| nat\_public\_ips | Public IPs of the NAT gateways, for allow-listing outbound traffic downstream. |
| public\_route\_table\_id | ID of the shared public route table. |
| private\_route\_table\_ids | Private route table IDs, keyed by availability zone. A gateway endpoint needs these. |
| default\_security\_group\_id | ID of the VPC default security group, which permits no traffic. |
| flow\_log\_group\_name | CloudWatch log group holding VPC flow logs, or null when flow logging is disabled. |
<!-- END_TF_DOCS -->
