# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`organization`** builds an AWS Organization, its organizational units and its member accounts. Units nest two levels so every `for_each` key is known at plan, and a child is addressed as `parent/child` wherever a unit is named. `create_organization = false` adopts an organization that already exists.
- **`organization-policy`** creates one organizational policy and attaches it to roots, units or accounts, keyed by a name so detaching one target leaves the others alone.
- **`iam-oidc-provider`** registers an OIDC issuer so a CI system assumes a role instead of holding an access key. It outputs the `aud` and `sub` condition keys built from the issuer host, so an `iam-role` trust states the host once and cannot disagree with the provider it names.
- **`amazon-mq`** builds a RabbitMQ or ActiveMQ broker. The two engines differ in deployment modes, users, storage and logging, and each difference is a precondition that stops the plan rather than an error AWS returns at apply with half a stack built.
- **`ses-domain`** verifies a sending domain with DKIM, a custom envelope sender and a configuration set, and either publishes the DNS records into Route 53 or lists them for a zone run elsewhere. An SMTP user is available and off by default, because an application that can call the SES API should use a role instead.
- **`kinesis-firehose`** delivers to S3 or to an HTTP endpoint, with the mandatory backup bucket the HTTP path needs. A plaintext endpoint URL is refused at plan, because the vendor access key would otherwise go on the wire in the clear.
- **`cloudwatch-metric-stream`** pushes metrics to a delivery stream rather than having a vendor poll `GetMetricData`. Include and exclude filters are mutually exclusive and the module says so at plan, and extra statistics are named per metric because they are billed that way.
- **Failure-path tests.** Both new modules test the direction that refuses as well as the direction that passes: a RabbitMQ broker asked for ActiveMQ's deployment mode, a multi-AZ broker given one subnet, an account in a unit that was never declared, an SES event destination with two targets, and a policy whose content is not JSON.

- **A policy lane.** `make policy` checks the conventions in `CONTRIBUTING.md` with conftest: no `provider` block in a module, a version on every required provider, a range rather than a pin, no `count` set to a length, no existence decided by whether a string is null, a `sensitive` marker on any credential-shaped string, and the same three files in every module. Seven rules, none of which duplicates checkov or tflint, and all of which could previously be broken with a green build.
- **Every policy rule is proved to still refuse.** `policy/tests/fixture` holds one module per rule, each breaking exactly one convention. The lane runs the repository, which must be silent, then every fixture, each of which must produce exactly one finding and the right one. A rule that quietly stops matching otherwise looks identical to a repository that is clean.
- `conftest` is pinned in `.tool-versions`, and a missing or mismatched version reports the lane as not run rather than counting it as a pass.
- Policy fixtures are stored as `*.tf.fixture` and named `.tf` only inside the runner's own copy. They are broken Terraform on purpose, and under a `.tf` name `trivy` and `tflint` report them as real findings on every commit.

### Changed

- **`CONTRIBUTING.md` named the wrong mechanism for pinning an example.** It asked for exact version constraints in examples; every example in fact uses a range and commits `.terraform.lock.hcl`, which is where an exact provider version and its hashes actually belong, and which `make clean` deliberately leaves alone. The rule now says so, and the policy lane checks the half that is real: a module states a range.

### Fixed

- The README said `make check` ran five lanes and quoted an old checkov count. It now lists all seven lanes, the `make plan-test` target and the current scan result.
- `make help` said `make clean` removes the examples' lock files. It doesn't: it removes the modules' lock files, and the examples' stay committed.

## [0.1.0] - 2026-09-10

The first release.

### Added

- **52 modules** covering conventions, networking, compute, load balancing, data, storage, messaging, data movement, edge and API, identity and secrets, and operations. Each has typed and described inputs, validation where a value can be checked at plan, and a README with generated tables.
- **11 examples** that compose the modules into stacks: a Magento storefront, a container platform with its ECR repositories, a serverless API, a static site behind CloudFront, a transit gateway hub, a Step Functions pipeline, an Airflow, DMS and Redshift warehouse, a partner SFTP exchange, an account baseline, a client VPN and an instance tier. Each README covers cost, the decisions that are deliberate, and what the example does not do.
- **Plan tests** covering every module, run against mock providers with `make plan-test`: each example plans the modules it composes, and each module no example uses has a test of its own. They evaluate every expression with real values — including IDs that do not exist until apply — which `terraform validate` does not, and they need no credentials.
- **`make check`**, which runs formatting, validation, the plan tests, tflint, checkov and a README freshness check, and reports a lane whose tool is missing rather than counting it as a pass.
- **`.tool-versions`**, pinning Terraform, tflint, terraform-docs and checkov. The check scripts refuse a mismatched version rather than report output that would differ.

### Conventions every module follows

- A collection that becomes resources is a map with static keys, so a plan never depends on a value that does not exist until apply.
- Whether a resource exists is decided by a bool or an object, never by whether a string is null.
- Encryption is on, public addresses are off and IMDSv2 is required, each with a variable to choose otherwise deliberately.
- No module carries a provider block.

[0.1.0]: https://github.com/kingletas/terraform-aws-modules/releases/tag/v0.1.0
