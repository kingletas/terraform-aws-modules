# acm-certificate

A certificate, its DNS validation records, and a wait for issuance.

## Usage

```hcl
module "certificate" {
  source = "github.com/kingletas/terraform-aws-modules//modules/acm-certificate?ref=v0.4.0"

  domain_name               = "example.com"
  subject_alternative_names = ["*.example.com"]
  zone_id                   = module.zone.zone_id
}
```

## Use `validated_arn`, not `arn`

`arn` exists as soon as the certificate is requested, while it is still pending. A listener that attaches to a pending certificate fails the apply.

`validated_arn` only resolves once issuance completes, so anything depending on it waits. Point load balancers and CloudFront at that one. With `wait_for_validation = false` it is the same value as `arn` and gives no such guarantee.

## Notes

- **CloudFront needs the certificate in us-east-1**, whatever region the rest of the stack lives in. Use an aliased provider.
- A wildcard such as `*.example.com` covers one label, so it matches `api.example.com` but **not** `example.com` itself and not `a.b.example.com`. Put the apex in `subject_alternative_names`.
- With `create_validation_records = false`, the module writes no validation records. The `validation_records` output lists them: give those to whoever runs the zone. The apply still waits for issuance while `wait_for_validation` is on, whoever writes the records, and fails after 75 minutes if they never appear.
- DNS validation renews on its own as long as the record stays in place. Email validation needs somebody to click a link every time.

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
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain\_name | Primary domain the certificate covers. | `string` | n/a | yes |
| subject\_alternative\_names | Extra domains on the same certificate. A wildcard such as *.example.com does not cover the apex. | `list(string)` | `[]` | no |
| validation\_method | DNS validates by a record and renews on its own. EMAIL needs somebody to click a link every renewal. | `string` | `"DNS"` | no |
| zone\_id | Route 53 zone to write validation records into. Null skips them, leaving validation to be done elsewhere. | `string` | `null` | no |
| create\_validation\_records | Write the DNS validation records into zone\_id. A bool rather than a null check on zone\_id, because a zone created in the same plan is not known to exist until apply. | `bool` | `true` | no |
| wait\_for\_validation | Block the apply until the certificate is issued, whether this module or someone else writes the validation records. Can take several minutes, and fails after 75 if the records never appear. | `bool` | `true` | no |
| key\_algorithm | Key algorithm. EC\_prime256v1 is smaller and faster than RSA\_2048; some older clients only speak RSA. | `string` | `"RSA_2048"` | no |
| certificate\_transparency\_logging | Log issuance to public certificate transparency logs. Turning it off hides internal host names, and some browsers then reject the certificate. | `bool` | `true` | no |
| tags | Tags applied to the certificate. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the certificate. Use validated\_arn where something must not attach before issuance. |
| validated\_arn | ARN that only resolves once the certificate is issued, so a listener cannot attach to a pending one. With wait\_for\_validation off it is the same as arn and gives no such guarantee. |
| domain\_name | Primary domain on the certificate. |
| status | Issuance status of the certificate. |
| validation\_records | DNS records proving domain control, keyed by domain. Give these to whoever runs the zone when it is not in Route 53. |
<!-- END_TF_DOCS -->
