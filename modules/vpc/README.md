# vpc

A VPC with public and private subnets spread across the availability zones you name, plus the routing to make them useful.

One public and one private subnet are created per zone. Public subnets share a route table pointing at an internet gateway. Each private subnet gets its own route table, so you can route each zone through its own NAT gateway and keep a zone failure contained.

Flow logging is on by default, writing to a CloudWatch log group this module creates along with the IAM role it needs.

## Usage

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=v0.1.0"

  name               = "platform"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "production"
  }
}
```

## How subnets are addressed

Subnets are carved from `cidr_block` with `cidrsubnet`. `subnet_newbits` decides how many bits are added to the VPC prefix, so a `/16` with the default `8` gives you `/24` subnets — 254 usable addresses each.

Public subnets take the first block per zone, private subnets continue where the public ones stop. With three zones and the defaults you get:

| Zone | Public | Private |
|---|---|---|
| First | `10.0.0.0/24` | `10.0.3.0/24` |
| Second | `10.0.1.0/24` | `10.0.4.0/24` |
| Third | `10.0.2.0/24` | `10.0.5.0/24` |

Adding a zone shifts the private range, which replaces subnets. Decide how many zones you want before you apply, or set `subnet_newbits` high enough to leave room.

## What this costs

A NAT gateway is billed hourly per zone plus per gigabyte processed, and it is usually the largest line on a small VPC's bill. Three of them cost three times as much as one.

- `enable_nat_gateway = false` if nothing in a private subnet needs outbound internet.
- `single_nat_gateway = true` to share one across every zone. Cheaper, and losing that zone takes outbound traffic down for all of them.

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
| availability\_zones | Availability zones to spread subnets across. One public and one private subnet are created per zone. | `list(string)` | n/a | yes |
| subnet\_newbits | Bits added to the VPC prefix when carving subnets. A /16 with 8 newbits yields /24 subnets. | `number` | `8` | no |
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
