# client-vpn

An AWS Client VPN endpoint: a managed OpenVPN server that puts a laptop inside your VPC.

Certificate, Active Directory and SAML authentication are all supported. Connection logging is on by default.

## Usage

```hcl
module "vpn" {
  source = "github.com/kingletas/terraform-aws-modules//modules/client-vpn?ref=v0.1.0"

  name              = "platform"
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  client_cidr_block = "10.100.0.0/22"

  security_group_ids = [module.vpn_sg.id]
  dns_servers        = [cidrhost(module.vpc.cidr_block, 2)]

  server_certificate_arn            = aws_acm_certificate.server.arn
  client_root_certificate_chain_arn = aws_acm_certificate.client_root.arn

  authorization_rules = {
    vpc = {
      target_network_cidr  = module.vpc.cidr_block
      description          = "Reach the whole VPC"
      authorize_all_groups = true
    }
  }
}
```

## Certificates

Either hand the module ACM ARNs, or hand it PEM material and let it import:

```hcl
server_certificate = {
  certificate_body  = file("pki/issued/server.crt")
  private_key       = file("pki/private/server.key")
  certificate_chain = file("pki/ca.crt")
}
```

Generate the certificates with [easy-rsa](https://github.com/OpenVPN/easy-rsa):

```bash
./easyrsa init-pki && ./easyrsa build-ca nopass
```

```bash
./easyrsa build-server-full server nopass && ./easyrsa build-client-full client nopass
```

The private keys are secrets. Keep them out of `.tfvars` files and out of git — pass them on the command line from disk, as `examples/client-vpn-cert-auth` shows.

## Authorization and routing

A client that connects can reach nothing until an authorization rule says otherwise. Each rule names a destination CIDR and either one Active Directory or SAML group, or every group:

```hcl
authorization_rules = {
  database_tier = {
    target_network_cidr = "10.0.16.0/20"
    description         = "Database subnets, platform engineers only"
    access_group_id     = "arn:aws:iam::…:role/PlatformEngineer"
  }
}
```

The CIDRs of associated subnets are routed for you. `routes` is for anything beyond them — a peered VPC, an on-premises range over a transit gateway, or `0.0.0.0/0` to send client internet traffic out through the VPC.

## What this costs

Two meters run, and the first one surprises people:

- **Each subnet association** is billed hourly from the moment it exists, whether or not anyone is connected. Associating three subnets triples that charge for availability you may not need on a development endpoint.
- **Each connected client** is billed hourly while connected.

## Notes

- `split_tunnel` is on, so only VPC-bound traffic enters the tunnel. Turning it off routes all of a client's internet traffic through AWS and is billed accordingly.
- `client_cidr_block` must be a `/22` or larger and must not overlap the VPC. It cannot be changed after the endpoint exists.
- Port 443 with UDP is the default. TCP gets through restrictive networks that block UDP, at some cost in throughput.
- The self-service portal requires federated authentication; the module rejects the combination at plan time rather than at apply.
- Older versions of the AWS provider mangled network associations on update, which was worked around with `ignore_changes`. That workaround is not carried here. If you see associations churn on an unrelated change, check the provider changelog before adding it back — the cost of `ignore_changes` is that the resource can no longer be updated at all.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9 |
| aws | >= 6.0, < 7.0 |

### Providers

| Name | Version |
| ---- | ------- |
| terraform | n/a |
| aws | >= 6.0, < 7.0 |

### Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.client_root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_ec2_client_vpn_authorization_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_authorization_rule) | resource |
| [aws_ec2_client_vpn_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint) | resource |
| [aws_ec2_client_vpn_network_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_network_association) | resource |
| [aws_ec2_client_vpn_route.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_route) | resource |
| [terraform_data.authentication_preconditions](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the endpoint and everything attached to it. | `string` | n/a | yes |
| client\_cidr\_block | Address pool handed to connecting clients. Must be at least a /22 and must not overlap the VPC. | `string` | n/a | yes |
| vpc\_id | VPC the endpoint is associated with. | `string` | n/a | yes |
| subnet\_ids | Subnets to associate the endpoint with, keyed by availability zone. Each association is billed hourly. The vpc module's private\_subnet\_ids output has this shape. | `map(string)` | n/a | yes |
| security\_group\_ids | Security groups applied to the endpoint's network interfaces. | `list(string)` | `[]` | no |
| authentication\_type | How clients authenticate: certificate-authentication, directory-service-authentication or federated-authentication. | `string` | `"certificate-authentication"` | no |
| server\_certificate\_arn | ACM ARN of the server certificate. Leave null to import server\_certificate instead. | `string` | `null` | no |
| server\_certificate | PEM material for the server certificate, imported into ACM. Ignored when server\_certificate\_arn is set. | <pre>object({<br/>    certificate_body  = string<br/>    private_key       = string<br/>    certificate_chain = optional(string)<br/>  })</pre> | `null` | no |
| client\_root\_certificate\_chain\_arn | ACM ARN of the client certificate authority. Required for certificate authentication unless client\_root\_certificate is set. | `string` | `null` | no |
| client\_root\_certificate | PEM material for the client certificate authority, imported into ACM. Ignored when client\_root\_certificate\_chain\_arn is set. | <pre>object({<br/>    certificate_body  = string<br/>    private_key       = string<br/>    certificate_chain = optional(string)<br/>  })</pre> | `null` | no |
| directory\_id | Directory Service directory ID. Required for directory-service-authentication. | `string` | `null` | no |
| saml\_provider\_arn | IAM SAML provider ARN. Required for federated-authentication. | `string` | `null` | no |
| self\_service\_saml\_provider\_arn | IAM SAML provider ARN backing the self-service portal. | `string` | `null` | no |
| authorization\_rules | Networks clients may reach, keyed by a stable name. Give each rule either an access\_group\_id or authorize\_all\_groups. | <pre>map(object({<br/>    target_network_cidr  = string<br/>    description          = optional(string)<br/>    access_group_id      = optional(string)<br/>    authorize_all_groups = optional(bool, false)<br/>  }))</pre> | n/a | yes |
| routes | Extra routes, keyed by a stable name. Associated subnet CIDRs are routed automatically and need no entry here. | <pre>map(object({<br/>    destination_cidr_block = string<br/>    target_subnet_id       = string<br/>    description            = optional(string)<br/>  }))</pre> | `{}` | no |
| split\_tunnel | Send only VPC-bound traffic through the tunnel. Turning this off routes all client internet traffic through AWS. | `bool` | `true` | no |
| dns\_servers | DNS servers pushed to clients. Use the VPC resolver, the base of the VPC CIDR plus two, to resolve private names. | `list(string)` | `[]` | no |
| vpn\_port | Port the endpoint listens on. | `number` | `443` | no |
| transport\_protocol | Transport protocol. UDP performs better; TCP traverses restrictive networks. | `string` | `"udp"` | no |
| session\_timeout\_hours | Hours before a connected client is forced to reauthenticate. | `number` | `8` | no |
| self\_service\_portal\_enabled | Offer the AWS self-service portal for client configuration downloads. Federated authentication only. | `bool` | `false` | no |
| connection\_log\_retention\_days | Days to retain connection logs. Set to 0 to disable connection logging. | `number` | `365` | no |
| connection\_log\_kms\_key\_arn | KMS key used to encrypt the connection log group. Defaults to the CloudWatch Logs service key. | `string` | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| id | ID of the Client VPN endpoint. |
| arn | ARN of the Client VPN endpoint. |
| dns\_name | DNS name clients connect to. Prefix it with a random string when the endpoint has multiple associations. |
| self\_service\_portal\_url | Self-service portal URL, or null when the portal is disabled. |
| server\_certificate\_arn | ACM ARN of the server certificate in use. |
| client\_root\_certificate\_chain\_arn | ACM ARN of the client certificate authority, or null for non-certificate authentication. |
| network\_association\_ids | Network association IDs, keyed by availability zone. |
| connection\_log\_group\_name | CloudWatch log group holding connection logs, or null when logging is disabled. |
<!-- END_TF_DOCS -->
