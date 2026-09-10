# vpc-peering

A peering connection between two VPCs, with the routes that make it usable.

## Usage

```hcl
module "peering" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc-peering?ref=v0.1.0"

  name             = "platform-to-data"
  requester_vpc_id = module.platform_vpc.vpc_id
  accepter_vpc_id  = module.data_vpc.vpc_id

  requester_route_table_ids  = values(module.platform_vpc.private_route_table_ids)
  requester_destination_cidr = module.data_vpc.cidr_block

  accepter_route_table_ids  = values(module.data_vpc.private_route_table_ids)
  accepter_destination_cidr = module.platform_vpc.cidr_block
}
```

## A connection without routes carries nothing

The peering connection is only half the work. Both sides need routes, and both sides need security groups that allow the other's CIDR. A connection sitting at `active` with no routes looks healthy and passes no traffic.

## Notes

- **Peering does not transit.** If A peers with B and B peers with C, A cannot reach C. That is what a transit gateway is for.
- **Overlapping CIDRs cannot be peered at all**, at any point in the future. It is worth planning address space before you need this.
- A cross-account connection stays at `pending-acceptance` until the other account accepts it, and the accepter's route tables cannot be managed from here.

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
| [aws_route.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.requester](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_vpc_peering_connection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the peering connection. | `string` | n/a | yes |
| requester\_vpc\_id | VPC asking for the connection, in this account and region. | `string` | n/a | yes |
| accepter\_vpc\_id | VPC being connected to. | `string` | n/a | yes |
| peer\_owner\_id | Account ID owning the other VPC. Null means the same account. | `string` | `null` | no |
| peer\_region | Region of the other VPC. Null means the same region. | `string` | `null` | no |
| auto\_accept | Accept the connection at once. Only possible when both VPCs are in this account and region. | `bool` | `true` | no |
| allow\_remote\_dns\_resolution | Let each side resolve the other's private hostnames to private addresses. | `bool` | `true` | no |
| requester\_route\_table\_ids | Keyed by a stable name, so the keys are known at plan. Route tables on this side that should reach the other VPC. | `map(string)` | `{}` | no |
| accepter\_route\_table\_ids | Keyed by a stable name, so the keys are known at plan. Route tables on the other side. Only usable when both VPCs are in this account and region. | `map(string)` | `{}` | no |
| requester\_destination\_cidr | CIDR of the other VPC, used in this side's routes. Required when requester\_route\_table\_ids is non-empty. | `string` | `null` | no |
| accepter\_destination\_cidr | CIDR of this VPC, used in the other side's routes. Required when accepter\_route\_table\_ids is non-empty. | `string` | `null` | no |
| tags | Tags applied to the peering connection. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the peering connection. |
| status | Status of the connection. A cross-account one sits at pending-acceptance until the other side accepts. |
| requester\_route\_ids | Route IDs created on this side, keyed by the name given to each route table. |
| accepter\_route\_ids | Route IDs created on the other side, keyed by the name given to each route table. |
<!-- END_TF_DOCS -->
