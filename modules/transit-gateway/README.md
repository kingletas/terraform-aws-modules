# transit-gateway

A transit gateway with attachments and route tables, for connecting more VPCs than peering can manage.

## Usage

```hcl
module "transit" {
  source = "github.com/kingletas/terraform-aws-modules//modules/transit-gateway?ref=v0.3.1"

  name = "platform"

  route_tables = {
    shared  = "Shared services, reachable by everything"
    spokes  = "Application VPCs, isolated from each other"
  }

  vpc_attachments = {
    platform = {
      vpc_id              = module.platform_vpc.vpc_id
      subnet_ids          = values(module.platform_vpc.private_subnet_ids)
      route_table_key     = "spokes"
      propagate_to_tables = ["shared"]
    }
  }
}
```

## Association and propagation are different things

- **Association** decides which route table an attachment *looks up* routes in. One per attachment.
- **Propagation** decides which route tables *learn* that attachment's routes. Any number.

Segmentation comes from the pair. Putting every spoke in a `spokes` table that propagates only to `shared` gives you hub-and-spoke: every VPC reaches shared services, none reaches its siblings. Getting these the wrong way round produces a mesh, quietly.

The module leaves the default association and propagation off, so an attachment is isolated until you say otherwise.

An attachment can be associated with only one route table. `route_table_key` therefore cannot be combined with `default_route_table_association = true`, and the plan fails if you set both.

## Static routes

Each entry in `static_routes` names a table with `route_table_key` and forwards to the attachment named by `attachment_key`. A blackhole route (`blackhole = true`) drops matching traffic and takes no `attachment_key`. The plan fails when a key does not name an entry in `route_tables` or `vpc_attachments`.

```hcl
static_routes = {
  on_premises = {
    route_table_key        = "shared"
    destination_cidr_block = "10.100.0.0/16"
    attachment_key         = "platform"
  }
  drop_legacy = {
    route_table_key        = "spokes"
    destination_cidr_block = "10.200.0.0/16"
    blackhole              = true
  }
}
```

## Notes

- A transit gateway is billed per attachment per hour plus per gigabyte, which is more than peering. It buys transitive routing and central control.
- `amazon_side_asn` cannot be changed after creation.
- Sharing through Resource Access Manager lets other accounts attach their own VPCs.

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
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route) | resource |
| [aws_ec2_transit_gateway_route_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_ram_principal_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name for the transit gateway. | `string` | n/a | yes |
| description | What this gateway connects. | `string` | `null` | no |
| amazon\_side\_asn | BGP ASN on the AWS side. Cannot be changed after creation. | `number` | `64512` | no |
| auto\_accept\_shared\_attachments | Accept attachments from other accounts without review. Off, so somebody has to approve each one. | `bool` | `false` | no |
| default\_route\_table\_association | Attach every new attachment to the default route table. Off gives each attachment its own table and real segmentation. | `bool` | `false` | no |
| default\_route\_table\_propagation | Propagate every attachment's routes into the default route table. | `bool` | `false` | no |
| dns\_support | Resolve public DNS to private addresses across attachments. | `bool` | `true` | no |
| multicast\_support | Enable multicast. Cannot be changed after creation. | `bool` | `false` | no |
| vpc\_attachments | VPC attachments keyed by a stable name. Use one subnet per availability zone you want reachable. route\_table\_key names the one table an attachment is associated with, and cannot be combined with default\_route\_table\_association. | <pre>map(object({<br/>    vpc_id              = string<br/>    subnet_ids          = list(string)<br/>    appliance_mode      = optional(bool, false)<br/>    dns_support         = optional(bool, true)<br/>    route_table_key     = optional(string)<br/>    propagate_to_tables = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| route\_tables | Route tables keyed by a stable name, with a description as the value. Segmentation is what a transit gateway is for. | `map(string)` | `{}` | no |
| static\_routes | Static routes keyed by a stable name. A route forwards to the attachment named by attachment\_key, or is a blackhole that drops traffic and names no attachment. | <pre>map(object({<br/>    route_table_key        = string<br/>    destination_cidr_block = string<br/>    attachment_key         = optional(string)<br/>    blackhole              = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| share\_with\_principals | Account IDs or organization ARNs to share the gateway with through Resource Access Manager. | `list(string)` | `[]` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the transit gateway. |
| arn | ARN of the transit gateway. |
| association\_default\_route\_table\_id | Default association route table, used by attachments that name no table of their own. |
| route\_table\_ids | Route table IDs, keyed by the name you gave each one. |
| vpc\_attachment\_ids | VPC attachment IDs, keyed by the name you gave each one. |
| resource\_share\_arn | Resource Access Manager share ARN, or null when the gateway is not shared. |
<!-- END_TF_DOCS -->
