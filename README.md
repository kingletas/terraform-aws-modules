# Terraform modules for AWS

[![CI](https://github.com/kingletas/terraform-aws-modules/actions/workflows/ci.yml/badge.svg)](https://github.com/kingletas/terraform-aws-modules/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Fifty-two reusable Terraform modules for AWS, drawn from infrastructure I've actually run: networking, compute, data, storage, messaging, edge, identity and operations.

Each module does one thing, and you compose them. Every input is typed, described and validated where it can be, and every collection is keyed by a name you choose rather than by list position. The `examples/` directory holds working compositions you can apply as they are.

## What's here

| Module | What it builds |
|---|---|
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
| [`alb`](modules/alb) | Target groups, an HTTPS listener, and HTTP answering with a redirect |
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
| **Data movement** | |
| [`dms-replication`](modules/dms-replication) | Replication instance, endpoints and tasks, with credentials from Secrets Manager |
| [`mwaa-environment`](modules/mwaa-environment) | Managed Airflow, private web server, per-component log levels |
| **Edge and API** | |
| [`cloudfront-distribution`](modules/cloudfront-distribution) | A distribution with origin access control and ordered behaviours |
| [`api-gateway-rest`](modules/api-gateway-rest) | A REST API with a deployed stage, logging and throttling |
| [`waf-web-acl`](modules/waf-web-acl) | Managed rule groups, rate limits and IP lists |
| **Identity and secrets** | |
| [`iam-role`](modules/iam-role) | Service, cross-account and OIDC trust, in one place |
| [`kms-key`](modules/kms-key) | A key with rotation and a policy built from named principals |
| [`secrets-manager-secret`](modules/secrets-manager-secret) | A secret, optionally generated, optionally rotated |
| [`ssm-parameter`](modules/ssm-parameter) | Parameters as a set, with values kept separately sensitive |
| [`acm-certificate`](modules/acm-certificate) | A certificate, its DNS validation, and a wait for issuance |
| [`cognito-user-pool`](modules/cognito-user-pool) | A user pool and app clients, with enumeration closed |
| **Operations** | |
| [`ansible-inventory`](modules/ansible-inventory) | The Terraform-to-Ansible handoff: inventory, facts and ssh config |
| [`cloudwatch-alarm`](modules/cloudwatch-alarm) | Alarms as a set, including metric maths |
| [`cloudwatch-dashboard`](modules/cloudwatch-dashboard) | A dashboard that lays its own widgets out |
| [`cloudwatch-log-group`](modules/cloudwatch-log-group) | Retention, metric filters and subscriptions |
| [`backup-plan`](modules/backup-plan) | A vault and plan, selecting resources by tag |
| [`cloudtrail-trail`](modules/cloudtrail-trail) | A multi-region trail with log file validation |
| [`transfer-server`](modules/transfer-server) | Managed SFTP over S3, each user confined to its prefix |

| Example | What it shows |
|---|---|
| [`magento`](examples/magento) | **Adobe Commerce, end to end**: CloudFront and WAF at the edge, an autoscaling web tier, the two nodes Magento can't replicate, Aurora, Valkey, OpenSearch and EFS, and configuration discovered by tag rather than written down |
| [`container-platform`](examples/container-platform) | **ECR and ECS Fargate**: a repository, service and target group per service, immutable tags, spot with an on-demand floor |
| [`serverless-api`](examples/serverless-api) | **API Gateway, Lambda, DynamoDB, SQS**: accept fast, process behind a queue |
| [`static-site-cdn`](examples/static-site-cdn) | **S3 and CloudFront**: origin access control, WAF, and the three things that must live in us-east-1 |
| [`network-hub`](examples/network-hub) | **Transit gateway**: hub and spokes, centralised NAT, optional site-to-site VPN |
| [`mwaa-data-warehouse`](examples/mwaa-data-warehouse) | **Airflow, DMS and Redshift**: replication from source systems into a warehouse, every credential in Secrets Manager |
| [`data-pipeline`](examples/data-pipeline) | **Step Functions batch load**: raw and curated zones, a run ledger, and alarms that tell "nothing to do" from "didn't run" |
| [`partner-sftp-exchange`](examples/partner-sftp-exchange) | **Transfer Family**: partners confined to their own prefix, seven years of transfer logs |
| [`account-baseline`](examples/account-baseline) | **CloudTrail and alarms**: root use, sign-in without MFA, trail tampering, backups by tag |
| [`client-vpn-cert-auth`](examples/client-vpn-cert-auth) | A VPN into a private VPC, authenticated by a certificate authority you run yourself |
| [`ec2-in-vpc`](examples/ec2-in-vpc) | Instances reachable through Session Manager, with no SSH key and nothing open inbound |

**The examples are the point.** Each one is a working composition with a README that says what it costs, which decisions are deliberate, and what it doesn't do. They carry the operational detail a module can't: why Magento gets exactly one cron node, why an SQS visibility timeout is six times the function timeout, why a spoke VPC has no NAT gateway of its own.

## Using a module

Point `source` at this repository and pin a tag. Without `ref`, `terraform init` takes whatever is on the default branch that day.

```hcl
module "vpc" {
  source = "github.com/kingletas/terraform-aws-modules//modules/vpc?ref=v0.1.0"

  name               = "platform"
  cidr_block         = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  tags = {
    Environment = "production"
  }
}
```

**While this repository is private, fetch it over SSH**: `git::ssh://git@github.com/kingletas/terraform-aws-modules.git//modules/vpc?ref=v0.1.0`. The shorter form above fails on authentication until then. [From nothing to a planned stack](docs/from-nothing.md) walks through both.

Or copy a module into your own repository. None of them depends on another module or on anything else here.

## Requirements

| | Version |
|---|---|
| Terraform | >= 1.9 |
| AWS provider | >= 6.0, < 7.0 |

Modules declare a wide range so they fit whatever you already run. The examples pin exactly and commit a lock file. A library says what it tolerates; a deployment says what it was tested against.

## Conventions

These hold across every module, so the next one you pick up behaves like the last.

- **Every input has a type and a description**, and anything that can be validated at plan time is. A bad CIDR fails before it reaches AWS.
- **Collections are keyed by a name you choose**, never by list position. Removing the second of three rules doesn't renumber the third.
- **Outputs are maps keyed the same way** as the inputs that produced them.
- **No provider blocks inside a module.** Modules declare what they need, and you configure it. A module with its own provider can't be used twice in one configuration.
- **No secrets on disk.** Nothing reads a certificate or key from a path baked into the module. Sensitive values arrive as marked variables.
- **Secure by default, with a way out.** Encryption on, public IPs off, IMDSv2 required, logging on. Each is a variable, so you can choose otherwise on purpose.

## Working on this

```bash
make help
```

```bash
make check
```

`make check` runs six lanes: formatting, validation, the plan tests, tflint, checkov and a check that every module README matches its code. Each tool's version is pinned in `.tool-versions`. **If a tool is missing or the wrong version, the lane says so and fails.** It never counts as a pass, because a green run that quietly skipped half its checks is worse than a red one.

| Target | What it does |
|---|---|
| `make fmt` | Rewrite every file to canonical formatting |
| `make validate` | Initialise and validate every module and example |
| `make plan-test` | Plan every example, and every module no example uses, against mock providers |
| `make lint` | Run tflint |
| `make security` | Run checkov |
| `make docs` | Regenerate the input and output tables in each module README |
| `make clean` | Remove `.terraform` directories and the modules' lock files |

The input and output tables in each module README are generated between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Don't edit them by hand: change the variable, then run `make docs`.

### Tools

| Tool | Needed for |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9 | everything |
| [checkov](https://www.checkov.io/) | `make security` |
| [tflint](https://github.com/terraform-linters/tflint) | `make lint` |
| [terraform-docs](https://terraform-docs.io/) | `make docs` |

## A note on checkov

The scan reports **1,184 passed, 0 failed and 15 skipped**. A check that can't pass is skipped with a reason, either on the resource it concerns as a `# checkov:skip=` comment, or in `.checkov.yml`, which turns it off for the whole repository. Every entry carries a comment. The reasons fall into four groups, and they're worth reading rather than trusting:

- **The caller decides, and checkov can't see across a module boundary.** Each of these is a variable on the module — access logging, enhanced monitoring, a customer-managed key. Checkov reads the declaration, not the value you pass, so it treats every one as unset.
- **A deployment concern no single module can satisfy.** Whether a volume is in a backup plan, or a load balancer sits behind a WAF, is true of a stack rather than of a resource. Answering it would mean one module reaching into another.
- **Checkov is wrong about the design.** It flags the ALB's plain HTTP listener for not using TLS 1.2, when that listener only exists to answer port 80 with a redirect. It flags `resources = ["*"]` in a KMS key policy, where it's required and means *this key*.
- **A real gap, named rather than hidden.** CloudFront origin failover isn't implemented yet. It's skipped on the distribution with a comment calling it a gap, so nobody mistakes it for a decision.

A check that can never pass stops being a check; people learn to scroll past it. **A repository that deploys these modules should run checkov with none of these skips**, because that's where they can be answered.

If you scan with trivy, three of its findings are deliberate and carry an inline `trivy:ignore` with the reason: all outbound traffic by default in `security-group`, a load balancer that can be public, and a port 80 listener that redirects once a certificate is set.

## What's been verified

Every module and example is checked statically, and every module is planned against mock providers, either through an example that uses it or through a test of its own. Nothing has been applied.

| Check | What it proves |
|---|---|
| `terraform fmt -check -recursive` | formatting |
| `terraform validate` | every module and example parses and type-checks with its variables unknown |
| **`terraform test` with mock providers** | **every module plans with real values**, including IDs that don't exist until apply — see below |
| `tflint` with the AWS ruleset | clean |
| `checkov` | clean, with each skip explained in `.checkov.yml` or on the resource |
| `terraform-docs --output-check` | every module README current |
| Applied against AWS or an emulator | **no** |

### Why the plan tests exist

`terraform validate` runs with every variable unknown, so it can't see an expression that only fails once real values arrive. The plan tests evaluate every example with invented but realistic values, against [mock providers](testing/mocks) that stand in for AWS. They need no credentials and create nothing.

They earned their place on their first run. Every module passed validation, and planning still found errors that would have broken a real first `terraform plan`:

- **Unknown `for_each` keys.** A collection keyed by values that don't exist until apply — a load balancer ARN, a subnet ID — can't be planned. Every collection that becomes resources is now a map with static keys.
- **`count` on whether a computed value is null.** Terraform can't tell that an unknown string isn't null until apply. Modules now decide whether a resource exists with a bool or an object, never a nullable string.
- **Conditionals between differently shaped objects**, which fail to evaluate or silently turn numbers into strings.
- **`coalesce(x, "")`**, which errors when `x` is null because `coalesce` skips empty strings.
- **Values the provider rejects** — a security policy name that didn't exist, and a log retention CloudWatch doesn't accept.

**A module you haven't planned is unproven.** Run `make plan-test` after changing one.

### What cannot be tested locally

**About twenty modules can't run against a local AWS emulator at all**, because the emulator doesn't implement the service: RDS and Aurora, OpenSearch, ElastiCache, DocumentDB, Redshift, MWAA, DMS, Transfer Family, CloudFront, WAF, Cognito, Transit Gateway, Client VPN, Backup and CloudTrail. They're planned and statically checked, and that's all.

## License

MIT. See [LICENSE](LICENSE).
