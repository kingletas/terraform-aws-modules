# site-to-site-vpn

An IPsec tunnel pair to an on-premises device, attached to a transit gateway or a virtual private gateway.

## Usage

```hcl
module "office" {
  source = "github.com/kingletas/terraform-aws-modules//modules/site-to-site-vpn?ref=v0.1.0"

  name                = "head-office"
  customer_gateway_ip = "203.0.113.10"
  transit_gateway_id  = module.transit.id

  static_routes_only = true
  static_routes      = ["192.168.0.0/16"]

  log_group_arn = aws_cloudwatch_log_group.vpn.arn
}
```

## Two tunnels, and only one is usually up

AWS always builds two tunnels to different endpoints. **With BGP, failover between them is automatic.** With `static_routes_only`, it is not — the far side has to decide, and many devices are configured for only the first tunnel. That works right up until AWS does maintenance on that endpoint.

Prefer BGP where the far side can speak it.

## Notes

- The pre-shared keys are in `customer_gateway_configuration`, which is marked sensitive. Hand it to the far side out of band, never in a ticket.
- Leaving `tunnel_preshared_keys` empty lets AWS generate them, which keeps them out of Terraform state.
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
| transit\_gateway\_id | Transit gateway to attach to. Set this or vpc\_id, not both. | `string` | `null` | no |
| vpc\_id | VPC to create a virtual private gateway in. Set this or transit\_gateway\_id, not both. | `string` | `null` | no |
| static\_routes\_only | Use static routes rather than BGP. BGP fails over on its own; static routes do not. | `bool` | `false` | no |
| static\_routes | CIDRs reachable at the far side. Required when static\_routes\_only is on. | `list(string)` | `[]` | no |
| local\_ipv4\_network\_cidr | CIDR on the far side allowed inside the tunnel. | `string` | `"0.0.0.0/0"` | no |
| remote\_ipv4\_network\_cidr | CIDR on the AWS side allowed inside the tunnel. | `string` | `"0.0.0.0/0"` | no |
| tunnel\_inside\_cidrs | The /30 ranges for each tunnel's inside addresses. Empty lets AWS choose. Must come from 169.254.0.0/16. | `list(string)` | `[]` | no |
| tunnel\_preshared\_keys | Pre-shared keys for each tunnel. Empty lets AWS generate them, which keeps them out of Terraform state. | `list(string)` | `[]` | no |
| propagate\_to\_route\_table\_ids | Route tables that learn routes from the virtual private gateway. Only used with vpc\_id. | `list(string)` | `[]` | no |
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
