# ses-domain

A verified sending domain: DKIM, a custom envelope sender, a configuration set, and the records the domain needs.

## Usage

```hcl
module "mail" {
  source = "github.com/kingletas/terraform-aws-modules//modules/ses-domain?ref=v0.7.0"

  domain              = "example.com"
  mail_from_subdomain = "mail"
  dmarc_policy        = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"

  create_dns_records = true
  zone_id            = module.zone.zone_id

  event_destinations = {
    problems = {
      matching_event_types = ["BOUNCE", "COMPLAINT", "REJECT", "RENDERING_FAILURE"]
      sns_topic_arn        = module.alerts.arn
    }
  }
}
```

## Three DNS records, and the domain sends nothing until they resolve

SES verifies a domain by reading DNS. Until the records are live, the identity exists and every send fails.

| Record | Why |
|---|---|
| Three DKIM `CNAME`s | Signs every message, so a receiver can tell it really came from you |
| `MX` on the MAIL FROM subdomain | Points the envelope sender at SES, so bounces come back |
| `TXT` SPF on the same subdomain | Says SES may send for that domain |

Set `create_dns_records = true` with a `zone_id` and the module publishes them. Leave it false and read the `dns_records` output, which lists every one of them including DMARC, for a zone somebody else runs.

**Set `mail_from_subdomain`.** Without it the envelope sender stays on an AWS domain, SPF authenticates against that rather than yours, and DMARC alignment fails on the SPF side. DKIM alignment still passes, so mail is usually delivered and the failure shows up only as a worse reputation and a DMARC report nobody reads.

## TLS is required by default, and that is a trade

`tls_policy` defaults to `REQUIRE`, so SES will not hand a message to a receiving server that refuses TLS. It bounces instead.

That is the right default and it is not free. A receiver still running without TLS never gets the message. The reason it is defensible here is that the bounce is **visible**: it raises a `BOUNCE` event, which is what the `event_destinations` above are for, and it lands on the account suppression list. Silent non-delivery is the failure worth avoiding, not the refusal.

Set `OPTIONAL` if you send to an audience you do not control and would rather deliver in the clear than not at all. Make it a decision, not a default you inherited.

## SMTP needs an IAM user, and most applications should not use SMTP

`create_smtp_user` is off. When it is on, the module creates an IAM user, an access key, and a policy that permits sending only through this identity and its configuration set, and only from addresses on this domain (`*@<domain>`).

That is a long-lived credential, which is what this library otherwise works hard to avoid. There is no way around it: **SMTP authenticates with a username and password and has nowhere to put a session token**, so a role cannot be used. The SES SMTP password is an IAM secret access key put through a derivation, which the AWS provider computes as `ses_smtp_password_v4`.

So the order of preference is:

1. **The SES API with a role.** Anything running on EC2, ECS or Lambda can do this, and no credential exists to leak.
2. **SMTP with this user**, when the application only speaks SMTP. Put `smtp_username` and `smtp_password` into Secrets Manager and rotate the key on a schedule.

`smtp_password` is a sensitive output and lands in Terraform state either way.

## Notes

- **A new account is in the sandbox**, which sends only to addresses you have verified, at a low rate. Moving out is a support request, not a Terraform change, and nothing here can do it for you.
- **The configuration set is attached to the identity**, so every send through this domain is attributed to it whether or not the caller names it. That is what makes the event destinations reliable.
- `suppressed_reasons` defaults to bounces and complaints, so a repeat send to a known-bad address never leaves the account. That protects reputation more than any single message is worth.
- **Easy DKIM is the default and AWS rotates the key.** `byodkim` takes that over, along with the rotation, which then belongs to whoever set it.
- **With `byodkim` set, the module publishes no DKIM record and `dns_records` lists none.** Easy DKIM's three CNAMEs do not apply. Publish one `TXT` record yourself at `<selector>._domainkey.<domain>`, with the value `p=` followed by the base64 public key matching `byodkim.private_key`. The module holds only the private key, so it cannot write that record for you. The MAIL FROM and DMARC records are still published as usual.

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
| [aws_iam_access_key.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_user.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_route53_record.dkim](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.dmarc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.mail_from_mx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.mail_from_spf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_sesv2_configuration_set.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sesv2_configuration_set) | resource |
| [aws_sesv2_configuration_set_event_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sesv2_configuration_set_event_destination) | resource |
| [aws_sesv2_email_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sesv2_email_identity) | resource |
| [aws_sesv2_email_identity_mail_from_attributes.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sesv2_email_identity_mail_from_attributes) | resource |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| domain | Domain to send from, such as example.com. Verifying a domain lets you send as any address on it. | `string` | n/a | yes |
| dkim\_key\_length | Key length for Easy DKIM, where AWS holds the private key and rotates it. | `string` | `"RSA_2048_BIT"` | no |
| byodkim | Sign with your own DKIM key instead of Easy DKIM. You then own the rotation, and AWS cannot do it for you. | <pre>object({<br/>    private_key = string<br/>    selector    = string<br/>  })</pre> | `null` | no |
| mail\_from\_subdomain | Subdomain for the envelope sender, such as mail, giving mail.example.com. Null leaves the AWS default, which fails SPF alignment. | `string` | `null` | no |
| behavior\_on\_mx\_failure | What SES does when the custom MAIL FROM records cannot be read. REJECT\_MESSAGE stops the send; USE\_DEFAULT\_VALUE falls back to the AWS domain and loses SPF alignment. | `string` | `"USE_DEFAULT_VALUE"` | no |
| tls\_policy | REQUIRE bounces a message the receiving server will not take over TLS. OPTIONAL delivers it in the clear instead. | `string` | `"REQUIRE"` | no |
| suppressed\_reasons | Reasons an address is added to the account suppression list, so a repeat send to a known-bad address never leaves. | `list(string)` | <pre>[<br/>  "BOUNCE",<br/>  "COMPLAINT"<br/>]</pre> | no |
| event\_destinations | Where sending events go, keyed by a name you choose. Each destination sets exactly one of sns\_topic\_arn or cloudwatch\_dimensions. | <pre>map(object({<br/>    matching_event_types = list(string)<br/>    enabled              = optional(bool, true)<br/>    sns_topic_arn        = optional(string)<br/>    cloudwatch_dimensions = optional(map(object({<br/>      source        = optional(string, "MESSAGE_TAG")<br/>      default_value = string<br/>    })))<br/>  }))</pre> | `{}` | no |
| create\_dns\_records | Publish the DKIM and MAIL FROM records into a Route 53 zone. False outputs them instead, for a zone run elsewhere. | `bool` | `false` | no |
| zone\_id | Route 53 zone to publish records into. Required when create\_dns\_records is true. | `string` | `null` | no |
| dmarc\_policy | DMARC record value published at \_dmarc. Null publishes none, which means no policy and no reports. | `string` | `null` | no |
| create\_smtp\_user | Create an IAM user and long-lived key for SMTP. Off, because an application that can call the SES API should use a role instead. | `bool` | `false` | no |
| smtp\_user\_name | Name for the SMTP user. Null names it after the domain. | `string` | `null` | no |
| tags | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the email identity. |
| domain | Domain that was verified. |
| verified | Whether SES has seen the DNS records and verified the identity. False until they resolve. |
| configuration\_set\_name | Configuration set every send through this identity is attributed to. |
| mail\_from\_domain | Envelope sender domain, or null when the AWS default is in use. |
| dns\_records | Every record the domain needs, whether or not this module published them. With byodkim set, the DKIM TXT record is not listed and is yours to publish. Give these to whoever runs the zone when it is not in Route 53. |
| smtp\_endpoint | SMTP host for this region. Port 587 with STARTTLS, or 465 with implicit TLS. |
| smtp\_username | SMTP username, which is the access key ID. Null when create\_smtp\_user is false. |
| smtp\_password | SMTP password, derived from the secret access key. Null when create\_smtp\_user is false. |
<!-- END_TF_DOCS -->
