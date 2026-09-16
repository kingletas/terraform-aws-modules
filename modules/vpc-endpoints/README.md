# vpc-endpoints

Interface and gateway endpoints, so a private subnet reaches AWS services without a NAT gateway.

## Usage

```hcl
module "endpoints" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc-endpoints?ref=v0.5.0"

  name   = "platform"
  vpc_id = module.vpc.vpc_id

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.endpoint_sg.id]
  route_table_ids    = values(module.vpc.private_route_table_ids)

  interface_services = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts"]
  gateway_services   = ["s3"]
}
```

## Gateway endpoints are free; interface endpoints are not

The **S3 and DynamoDB gateway endpoints cost nothing** and remove the largest slice of NAT gateway data charges most stacks have. There is rarely a reason not to add them.

An **interface endpoint is billed hourly per availability zone, plus per gigabyte**. Five services across three zones is fifteen hourly charges before any traffic. That can still beat a NAT gateway, or not. It depends on volume, and it is worth doing the arithmetic rather than assuming either way.

## Notes

- Pulling a container image needs **both** `ecr.api` and `ecr.dkr`, and also the S3 gateway endpoint, because the layers live in S3. Missing any of the three leaves image pulls timing out.
- `private_dns_enabled` is what lets the service's normal hostname resolve to the endpoint, so callers need no code change.
- The endpoint security group needs HTTPS from the callers.

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
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for the endpoints. | `string` | n/a | yes |
| vpc\_id | VPC the endpoints belong to. | `string` | n/a | yes |
| subnet\_ids | Subnets for interface endpoints. One per availability zone. | `list(string)` | `[]` | no |
| security\_group\_ids | Security groups on the interface endpoints. They need HTTPS from the callers. | `list(string)` | `[]` | no |
| route\_table\_ids | Route tables that gateway endpoints add a prefix list route to. | `list(string)` | `[]` | no |
| interface\_services | Service short names for interface endpoints, such as ecr.api, logs, secretsmanager. Each is billed hourly per availability zone, plus data. | `list(string)` | `[]` | no |
| gateway\_services | Service short names for gateway endpoints. Only s3 and dynamodb exist, and both are free. | `list(string)` | <pre>[<br/>  "s3"<br/>]</pre> | no |
| private\_dns\_enabled | Let the service's public hostname resolve to the endpoint, so callers need no code change. | `bool` | `true` | no |
| policy\_json | Endpoint policy applied to every endpoint. Null uses full access, which the surrounding IAM still constrains. | `string` | `null` | no |
| tags | Tags applied to every endpoint. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| interface\_endpoint\_ids | Interface endpoint IDs, keyed by service short name. |
| interface\_dns\_names | Private DNS names of each interface endpoint, keyed by service short name. |
| gateway\_endpoint\_ids | Gateway endpoint IDs, keyed by service short name. |
| gateway\_prefix\_list\_ids | Prefix list ID of each gateway endpoint, for use in a security group rule. |
<!-- END_TF_DOCS -->
