# Terraform modules for AWS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Fifty-nine reusable Terraform modules for AWS, covering multi-account setup, networking, compute, data, storage, messaging, edge, identity and operations, and eleven examples that compose them into complete stacks.

Each module does one thing, and you compose them. Every input is typed, described and validated where it can be, and every collection is keyed by a name you choose rather than by list position.

New here? [From nothing to a planned stack](docs/from-nothing.md) takes you from a clone to a planned example, without an AWS account, in about ten minutes.

## Contents

- [What's here](#whats-here)
- [Using a module](#using-a-module)
- [Versioning and pinning](#versioning-and-pinning)
- [Requirements](#requirements)
- [Conventions](#conventions)
- [Testing](#testing)
- [Working on this repository](#working-on-this-repository)
- [License](#license)

## What's here

| Module | What it builds |
|---|---|
| **Multi-account** | |
| [`organization`](modules/organization) | The organization, its units, and the member accounts inside them |
| [`organization-policy`](modules/organization-policy) | A service control policy and everything it attaches to |
| **Conventions** | |
| [`context`](modules/context) | Names, tags and every environment-dependent default, in one place |
| [`account-defaults`](modules/account-defaults) | Account-wide settings above per-resource ones: EBS encryption, S3 public access, password policy |
| **Networking** | |
| [`vpc`](modules/vpc) | Public and private subnets per zone, per-zone route tables, optional NAT, flow logs |
| [`security-group`](modules/security-group) | A group whose rules are separate, named, individually addressable resources |
| [`vpc-endpoints`](modules/vpc-endpoints) | Interface and gateway endpoints, so a private subnet skips the NAT gateway |
| [`vpc-peering`](modules/vpc-peering) | A peering connection and the routes on both sides |
| [`transit-gateway`](modules/transit-gateway) | Attachments and route tables, for hub-and-spoke across many VPCs |
| [`route53-zone`](modules/route53-zone) | A hosted zone, its records and its health checks |
| [`client-vpn`](modules/client-vpn) | Client VPN with certificate, directory or SAML authentication |
| [`site-to-site-vpn`](modules/site-to-site-vpn) | An IPsec tunnel pair to an on-premises device |
| **Compute** | |
| [`ec2-instance`](modules/ec2-instance) | Instances with stable names, IMDSv2 required, encrypted volumes |
| [`launch-template`](modules/launch-template) | How an instance is built, for a scaling group to use |
| [`autoscaling-group`](modules/autoscaling-group) | Scaling with instance refresh and target tracking |
| [`ecs-cluster`](modules/ecs-cluster) | A cluster with Container Insights and recorded exec sessions |
| [`ecs-service`](modules/ecs-service) | A task definition and service, with a deployment circuit breaker |
| [`lambda-function`](modules/lambda-function) | A function with a managed log group and its event sources |
| [`instance-fleet`](modules/instance-fleet) | EC2 instances in named roles, each a variation on one base spec |
| [`ssh-key-pair`](modules/ssh-key-pair) | A key pair, supplied or generated, private half in Secrets Manager |
| **Load balancing** | |
| [`alb`](modules/alb) | Target groups, an HTTPS listener with host, path and header rules, and HTTP answering with a redirect |
| [`nlb`](modules/nlb) | TCP and TLS listeners for what an ALB can't carry |
| **Data** | |
| [`rds-instance`](modules/rds-instance) | A managed database whose password AWS holds, not Terraform |
| [`aurora-cluster`](modules/aurora-cluster) | A writer and readers, defaulting to Serverless v2 |
| [`elasticache-redis`](modules/elasticache-redis) | Valkey or Redis, encrypted in flight and at rest |
| [`opensearch-domain`](modules/opensearch-domain) | A search domain in your VPC, HTTPS enforced |
| [`documentdb-cluster`](modules/documentdb-cluster) | A MongoDB-compatible cluster with TLS and audit logs |
| [`redshift-cluster`](modules/redshift-cluster) | A warehouse with enhanced VPC routing and audit logging |
| [`dynamodb-table`](modules/dynamodb-table) | A table with point-in-time recovery and deletion protection |
| **Storage** | |
| [`s3-bucket`](modules/s3-bucket) | Private, encrypted, versioned, and refusing plain HTTP |
| [`efs-filesystem`](modules/efs-filesystem) | Shared POSIX storage with per-path access points |
| [`ecr-repository`](modules/ecr-repository) | A registry with immutable tags and a lifecycle policy |
| **Messaging** | |
| [`sqs-queue`](modules/sqs-queue) | A queue and the dead letter queue it needs |
| [`sns-topic`](modules/sns-topic) | A topic and its subscriptions |
| [`eventbridge-rule`](modules/eventbridge-rule) | A rule and targets, on a schedule or an event pattern |
| [`step-function`](modules/step-function) | A state machine, for work one function shouldn't orchestrate |
| [`amazon-mq`](modules/amazon-mq) | Managed RabbitMQ or ActiveMQ, private to your VPC |
| [`kinesis-firehose`](modules/kinesis-firehose) | Buffered delivery to S3 or an HTTP endpoint, with a bucket behind it |
| **Data movement** | |
| [`dms-replication`](modules/dms-replication) | Replication instance, endpoints and tasks, with credentials from Secrets Manager |
| [`mwaa-environment`](modules/mwaa-environment) | Managed Airflow, private web server, per-component log levels |
| **Edge and API** | |
| [`cloudfront-distribution`](modules/cloudfront-distribution) | A distribution with origin access control and ordered behaviours |
| [`api-gateway-rest`](modules/api-gateway-rest) | A REST API with a deployed stage, logging and throttling |
| [`ses-domain`](modules/ses-domain) | A verified sending domain: DKIM, envelope sender, and the records it needs |
| [`waf-web-acl`](modules/waf-web-acl) | Managed rule groups, rate limits and IP lists |
| **Identity and secrets** | |
| [`iam-role`](modules/iam-role) | Service, cross-account and OIDC trust, in one place |
| [`iam-oidc-provider`](modules/iam-oidc-provider) | An OIDC issuer IAM will accept, so CI needs no stored key |
| [`kms-key`](modules/kms-key) | A key with rotation and a policy built from named principals |
| [`secrets-manager-secret`](modules/secrets-manager-secret) | A secret, optionally generated, optionally rotated |
| [`ssm-parameter`](modules/ssm-parameter) | Parameters as a set, with values kept separately sensitive |
| [`acm-certificate`](modules/acm-certificate) | A certificate, its DNS validation, and a wait for issuance |
| [`cognito-user-pool`](modules/cognito-user-pool) | A user pool and app clients, with enumeration closed |
| **Operations** | |
| [`ansible-inventory`](modules/ansible-inventory) | The Terraform-to-Ansible handoff: inventory, facts and ssh config |
| [`cloudwatch-alarm`](modules/cloudwatch-alarm) | Alarms as a set, including metric maths |
| [`cloudwatch-dashboard`](modules/cloudwatch-dashboard) | A dashboard built from typed widgets, with a console link |
| [`cloudwatch-log-group`](modules/cloudwatch-log-group) | Retention, metric filters and subscriptions |
| [`cloudwatch-metric-stream`](modules/cloudwatch-metric-stream) | Metrics pushed to a delivery stream instead of polled for |
| [`backup-plan`](modules/backup-plan) | A vault and plan, selecting resources by tag |
| [`cloudtrail-trail`](modules/cloudtrail-trail) | A multi-region trail with log file validation |
| [`transfer-server`](modules/transfer-server) | Managed SFTP over S3, each user confined to its home directory |

| Example | What it shows |
|---|---|
| [`magento`](examples/magento) | **Adobe Commerce, end to end**: CloudFront and WAF at the edge, an autoscaling web tier, single nodes for cron and the admin panel, Aurora, Valkey, OpenSearch and EFS, and configuration discovered by tag rather than written down |
| [`container-platform`](examples/container-platform) | **ECR and ECS Fargate**: a repository, service and target group per service, Fargate Spot above an on-demand task, immutable tags, path-based routing behind one load balancer |
| [`serverless-api`](examples/serverless-api) | **API Gateway, Lambda, DynamoDB, SQS**: accept fast, process behind a queue |
| [`static-site-cdn`](examples/static-site-cdn) | **S3 and CloudFront**: origin access control, WAF, and the resources CloudFront needs in us-east-1 |
| [`network-hub`](examples/network-hub) | **Transit gateway**: hub and spokes, centralised NAT, optional site-to-site VPN |
| [`mwaa-data-warehouse`](examples/mwaa-data-warehouse) | **Airflow, DMS and Redshift**: replication from source systems into a warehouse, every credential in Secrets Manager |
| [`data-pipeline`](examples/data-pipeline) | **Step Functions batch load**: raw and curated zones, a run ledger, and alarms that tell "nothing to do" from "didn't run" |
| [`partner-sftp-exchange`](examples/partner-sftp-exchange) | **Transfer Family**: partners confined to their own prefix, seven years of transfer logs, alarms on failed partner logins |
| [`account-baseline`](examples/account-baseline) | **CloudTrail and alarms**: root use, sign-in without MFA, trail tampering, backups by tag |
| [`client-vpn-cert-auth`](examples/client-vpn-cert-auth) | A VPN into a private VPC, authenticated by a certificate authority you run yourself |
| [`ec2-in-vpc`](examples/ec2-in-vpc) | Instances reachable through Session Manager, with no SSH key and nothing open inbound |

Each example is a working composition with a README that covers what it builds, what must exist before you deploy it, what it costs, and its limits. The examples carry the operational detail a module cannot: why Magento gets exactly one cron node, why an SQS visibility timeout is six times the function timeout, why a spoke VPC has no NAT gateway of its own.

The examples call modules with relative paths (`../../modules/<name>`) so they always use the code beside them. If you copy an example into your own repository, change each `source` to the Git form shown below.

## Using a module

Point `source` at a module in this repository and pin a release with `?ref=`:

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=v0.3.0"

  name               = "platform"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  tags = {
    Environment = "production"
  }
}
```

Then run `terraform init` to fetch it. Each module's README lists every input and output, with a usage example. Required inputs have no default; everything else has a safe one.

No module depends on another module in this repository, so you can also copy a single module directory into your own codebase.

## Versioning and pinning

Releases are tagged `vMAJOR.MINOR.PATCH` and follow [semantic versioning](https://semver.org/). Before 1.0, a minor release (for example `v0.3.0` to `v0.4.0`) may change module interfaces or behaviour. A patch release does not. [CHANGELOG.md](CHANGELOG.md) lists every breaking change with what a caller has to do, so read it before you move to a new minor version.

Always pin a `ref`. Without one, `terraform init` takes whatever is on the default branch at the time.

A tag is the readable choice. A commit SHA is the stronger one, because a tag can be moved and a commit cannot. Pin the SHA and keep the tag in a comment so readers and update tools know which release it is:

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=<commit-sha>" # v0.3.0

  # ...
}
```

Replace `<commit-sha>` with the full 40-character commit SHA. `git ls-remote --tags https://github.com/kingletas/terraform-aws-modules.git` lists it on the line ending `refs/tags/v0.3.0^{}`, which is the commit the tag points to.

## Requirements

| | Version |
|---|---|
| Terraform | >= 1.9 |
| AWS provider | >= 6.0, < 7.0 |

`dynamodb-table` needs AWS provider 6.37.0 or later. A few modules also need the `random`, `tls` or `local` provider; each module's README lists its providers.

Modules declare a version range so they fit the provider version you already run. The examples declare a range too (`~> 6.0`) and commit a `.terraform.lock.hcl`, which records the exact provider version and checksums they were tested with.

## Conventions

These hold across every module, so the next one you pick up behaves like the last.

- **Every input has a type and a description**, and anything that can be validated at plan time is. A bad CIDR fails before it reaches AWS.
- **Collections are keyed by a name you choose**, never by list position. Removing the second of three rules does not renumber the third.
- **Outputs are maps keyed the same way** as the inputs that produced them.
- **No provider blocks inside a module.** Modules declare what they need, and you configure it. A module with its own provider cannot be used twice in one configuration.
- **No secrets on disk.** Nothing reads a certificate or key from a path baked into the module. Sensitive values arrive as variables marked `sensitive`.
- **Secure by default, with a way out.** Encryption on, public addresses off, IMDSv2 required, logging on. Each is a variable, so you can choose otherwise on purpose.

## Testing

Every module is planned by `terraform test` against [mock providers](testing/mocks): stand-ins for AWS that need no credentials and create nothing. A module is planned either through an example that composes it or by a test of its own in `modules/<name>/tests/`. Planning with real values catches errors `terraform validate` cannot see, because `validate` treats every variable as unknown: a `for_each` keyed on a value that only exists after apply, or a provider argument AWS would reject.

The tests assert on the planned values, and include refusal tests: runs that set invalid inputs and expect a named validation or precondition to stop the plan.

To run one module's or one example's tests:

```bash
terraform -chdir=modules/vpc init -backend=false && terraform -chdir=modules/vpc test
```

`make check` runs everything a change has to pass:

| Lane | Tool | What it checks |
|---|---|---|
| format | `terraform fmt` | Canonical formatting |
| validate | `terraform validate` | Every module and example initialises and type-checks |
| plan | `terraform test` | Every example and module test plans against mock providers |
| lint | [tflint](https://github.com/terraform-linters/tflint) with the AWS ruleset | Naming, typed and documented variables and outputs, provider rules |
| security | [checkov](https://www.checkov.io/) | Security misconfiguration in the resources |
| policy | [conftest](https://www.conftest.dev/) | This repository's own conventions; see [`policy/`](policy) |
| docs | [terraform-docs](https://terraform-docs.io/) | Every module README's tables match its variables and outputs |

The tests do not create resources in AWS. Before you rely on a module in production, apply it in an account where a mistake is cheap, and read its README for prerequisites such as account-level roles or settings.

### Scanner exceptions

A checkov check that cannot apply to a reusable module is skipped with a reason, either inline on the resource as a `# checkov:skip=` comment or for the whole repository in [`.checkov.yml`](.checkov.yml). Most repository-wide skips are checks that depend on a value the caller passes, or on the stack around the module, such as whether a load balancer sits behind a WAF. Run checkov over the configuration that deploys these modules, where those questions can be answered.

If you scan with trivy, three findings carry an inline `trivy:ignore` with the reason: all outbound traffic by default in `security-group`, a load balancer that can be public, and a port 80 listener that redirects to HTTPS.

## Working on this repository

```bash
make help
```

| Target | What it does |
|---|---|
| `make check` | Run every lane above; a lane whose tool is missing or the wrong version fails |
| `make fmt` | Rewrite every file to canonical formatting |
| `make fmt-check` | Fail if any file is not canonically formatted |
| `make validate` | Initialise and validate every module and example |
| `make plan-test` | Plan every example, and every module with its own test, against mock providers |
| `make lint` | Run tflint over every module and example |
| `make security` | Run checkov over the repository |
| `make policy` | Check this repository's conventions, and that each rule still refuses the case it exists for |
| `make docs` | Regenerate the input and output tables in each module README |
| `make docs-check` | Fail if a module README's tables are out of date |
| `make clean` | Remove `.terraform` directories and the modules' lock files |

The tool versions are pinned in [`.tool-versions`](.tool-versions):

| Tool | Needed for |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | everything |
| [tflint](https://github.com/terraform-linters/tflint) | `make lint` |
| [checkov](https://www.checkov.io/) | `make security` |
| [conftest](https://www.conftest.dev/) | `make policy` |
| [terraform-docs](https://terraform-docs.io/) | `make docs`, `make docs-check` |

The input and output tables in each module README are generated between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Do not edit them by hand: change the variable or output, then run `make docs`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for adding a module, and [SECURITY.md](SECURITY.md) for reporting a vulnerability.

## License

MIT. See [LICENSE](LICENSE).
