# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`organization`** builds an AWS Organization, its organizational units and its member accounts. Units nest two levels so every `for_each` key is known at plan, and a child is addressed as `parent/child` wherever a unit is named. `create_organization = false` adopts an organization that already exists.
- **`organization-policy`** creates one organizational policy and attaches it to roots, units or accounts, keyed by a name so detaching one target leaves the others alone.
- **Failure-path tests.** Both new modules test the direction that refuses as well as the direction that passes: an account in a unit that was never declared, policy types without the `ALL` feature set, an address that is not an email, content that is not JSON, and a target that is not an AWS identifier.

### Fixed

- The README said `make check` ran five lanes and quoted an old checkov count. It now lists all six lanes, the `make plan-test` target and the current scan result.
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
