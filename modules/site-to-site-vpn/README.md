# site-to-site-vpn

An IPsec tunnel pair to an on-premises device, attached to a transit gateway or a virtual private gateway.

## Usage

```hcl
module "office" {
  source = "github.com/kingletas/terraform-aws-modules//modules/site-to-site-vpn?ref=v0.7.0"

  name                = "head-office"
  customer_gateway_ip = "203.0.113.10"
  transit_gateway_id  = module.transit.id

  static_routes_only = true
  static_routes      = { head_office = "192.168.0.0/16" }

  transit_gateway_association         = { route_table_id = module.transit.route_table_ids["hub"] }
  transit_gateway_static_route_tables = {
    hub    = module.transit.route_table_ids["hub"]
    spokes = module.transit.route_table_ids["spokes"]
  }

  log_group_arn = aws_cloudwatch_log_group.vpn.arn
}
```

## Attaching to a transit gateway or a virtual private gateway

Set exactly one of `transit_gateway_id` and `vpn_gateway`. The plan fails if you set both or neither.

| | With `transit_gateway_id` | With `vpn_gateway = { vpc_id = ... }` |
|---|---|---|
| What it creates | The VPN attachment on your transit gateway | A virtual private gateway in that VPC |
| Where `static_routes` go | A route to each CIDR in every table in `transit_gateway_static_route_tables` | VPN connection routes |
| Route table association | `transit_gateway_association` | Not applicable |
| Learning BGP routes | `transit_gateway_propagation_route_tables` | `vpn_gateway_propagation_route_tables` (VPC route tables) |

`static_routes` and every route table input are maps keyed by a name you choose, so removing one entry does not disturb the others.

**Static routing with a transit gateway needs `transit_gateway_static_route_tables`.** The routes to the far side live in transit gateway route tables, not on the VPN connection, so without it nothing reaches the far side. The plan fails if it is missing.

`transit_gateway_association` sets the transit gateway route table the VPN attachment looks up routes in. Leave it null when the transit gateway associates new attachments with its default route table, because an attachment can be associated with only one table. The `transit_gateway_*` inputs are rejected with `vpn_gateway`, and `vpn_gateway_propagation_route_tables` is rejected with `transit_gateway_id`.

## Two tunnels, and only one is usually up

AWS always builds two tunnels to different endpoints. **With BGP, failover between them is automatic.** With `static_routes_only`, it is not. The far side has to decide, and many devices are configured for only the first tunnel. That works right up until AWS does maintenance on that endpoint.

Prefer BGP where the far side can speak it.

## Notes

- The pre-shared keys are in `customer_gateway_configuration`, which is marked sensitive. Hand it to the far side out of band, never in a ticket.
- Leaving `tunnel_preshared_keys` empty lets AWS generate them, which keeps them out of your configuration but not out of Terraform state. The provider reads the generated keys back into state as `tunnel1_preshared_key` and `tunnel2_preshared_key`, and they also appear in `customer_gateway_configuration`. Treat the state as holding the keys either way, and keep it encrypted with access restricted.
- `tunnel_inside_cidrs` must come from `169.254.0.0/16` and must not collide with any other tunnel on the same gateway.
- Tunnel logging is what tells you why a tunnel dropped. Without it, a flapping tunnel is invisible.

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
| [aws_customer_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_ec2_transit_gateway_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route) | resource |
| [aws_ec2_transit_gateway_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_vpn_connection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [aws_vpn_connection_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection_route) | resource |
| [aws_vpn_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_gateway) | resource |
| [aws_vpn_gateway_route_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_gateway_route_propagation) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the connection and its gateways. | `string` | n/a | yes |
| customer\_gateway\_ip | Public IP of the device at the other end. The far side owns this, so confirm it rather than guessing. | `string` | n/a | yes |
| customer\_gateway\_bgp\_asn | BGP ASN of the far side. Use 65000 when the far side does not run BGP. | `number` | `65000` | no |
| customer\_gateway\_certificate\_arn | ACM certificate for certificate-based authentication instead of a pre-shared key. | `string` | `null` | no |
| transit\_gateway\_id | Transit gateway to attach to. Set this or vpn\_gateway, not both. | `string` | `null` | no |
| vpn\_gateway | Creates a virtual private gateway in this VPC and attaches the connection to it. Set this or transit\_gateway\_id, not both. | <pre>object({<br/>    vpc_id = string<br/>  })</pre> | `null` | no |
| static\_routes\_only | Use static routes rather than BGP. BGP fails over on its own; static routes do not. | `bool` | `false` | no |
| static\_routes | CIDRs reachable at the far side, keyed by a stable name. Required when static\_routes\_only is on. With vpn\_gateway they become VPN connection routes; with transit\_gateway\_id they become routes in transit\_gateway\_static\_route\_tables. | `map(string)` | `{}` | no |
| local\_ipv4\_network\_cidr | CIDR on the far side allowed inside the tunnel. | `string` | `"0.0.0.0/0"` | no |
| remote\_ipv4\_network\_cidr | CIDR on the AWS side allowed inside the tunnel. | `string` | `"0.0.0.0/0"` | no |
| tunnel\_inside\_cidrs | The /30 ranges for each tunnel's inside addresses. Empty lets AWS choose. Must come from 169.254.0.0/16. | `list(string)` | `[]` | no |
| tunnel\_preshared\_keys | Pre-shared keys for each tunnel. Empty lets AWS generate them. Either way the keys are stored in Terraform state. | `list(string)` | `[]` | no |
| vpn\_gateway\_propagation\_route\_tables | VPC route tables that learn routes from the virtual private gateway, keyed by a stable name. Only with vpn\_gateway. | `map(string)` | `{}` | no |
| transit\_gateway\_association | Transit gateway route table the VPN attachment looks up routes in. Only with transit\_gateway\_id, and not when the gateway associates new attachments with its default table. Null leaves the attachment unassociated. | <pre>object({<br/>    route_table_id = string<br/>  })</pre> | `null` | no |
| transit\_gateway\_propagation\_route\_tables | Transit gateway route tables that learn the far side's BGP routes, keyed by a stable name. Only with transit\_gateway\_id. | `map(string)` | `{}` | no |
| transit\_gateway\_static\_route\_tables | Transit gateway route tables that get a route to each static\_routes CIDR through the VPN attachment, keyed by a stable name. Required for static routing with transit\_gateway\_id. | `map(string)` | `{}` | no |
| enable\_tunnel\_logging | Log tunnel state changes to CloudWatch, which is how you find out why a tunnel dropped. | `bool` | `true` | no |
| log\_group\_arn | CloudWatch log group for tunnel logs. Required when enable\_tunnel\_logging is on. | `string` | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| connection\_id | ID of the VPN connection. |
| customer\_gateway\_id | ID of the customer gateway. |
| vpn\_gateway\_id | ID of the virtual private gateway, or null when attached to a transit gateway. |
| tunnel\_addresses | Public addresses of the two AWS-side tunnel endpoints. The far side's device points at these. |
| tunnel\_inside\_cidrs | Inside address ranges of each tunnel. |
| customer\_gateway\_configuration | Device configuration for the far side, including the pre-shared keys. Hand it over out of band. |
| transit\_gateway\_attachment\_id | Transit gateway attachment ID, or null when attached to a virtual private gateway. |
<!-- END_TF_DOCS -->
