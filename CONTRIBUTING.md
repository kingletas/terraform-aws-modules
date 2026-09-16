# Contributing

## Before you open a pull request

```bash
make check
```

Everything has to pass. If a lane cannot run because a tool is missing or is the wrong version, `make check` says so and fails. Install the version pinned in `.tool-versions` rather than working around the message.

To run the tests for one module or example while you work on it:

```bash
terraform -chdir=modules/<name> init -backend=false && terraform -chdir=modules/<name> test
```

The same works for `examples/<name>`.

## Adding a module

A module goes in `modules/<name>/`:

| File | Holds | Checked by |
|---|---|---|
| `versions.tf` | `required_version` and `required_providers`, and nothing else | `make policy` fails without it |
| `variables.tf` | Every input, each with a type and a description | `make policy` fails without it; `make lint` fails on an input with no type or description |
| `outputs.tf` | Every output, each with a description | `make policy` fails without it; `make lint` fails on an output with no description |
| `main.tf` | Resources. Split into further files when one gets long | Convention |
| `README.md` | Prose, plus the generated tables between the `TF_DOCS` markers | Convention; `make docs-check` fails when the tables are out of date |
| `tests/plan.tftest.hcl` | A plan test, when no example already uses the module | Convention |

Then prove it plans. Use it in an example under `examples/`, whose `tests/plan.tftest.hcl` plans every module the example calls, or give the module a `tests/plan.tftest.hcl` of its own. `terraform validate` alone will not tell you it works, because it runs with every variable unknown. `make plan-test` runs every example's test and every module test with real values against mock providers.

A good module test also checks the direction that refuses: a `run` block with `expect_failures` for each validation or precondition, so a rule that stops matching fails the test.

If a plan test needs a value only AWS would know, like a certificate's validation records or a realistic ARN, state it with an `override_resource` and `override_during = plan`. Shared mock values live in `testing/mocks/`. Keep mock values plainly fake: a string shaped like a private key is refused by secret scanners, even in a test.

## What the modules agree on

Follow these so the next module behaves like the last one:

- **No `provider` blocks in a module.** Declare what it needs and let the caller configure it. A module with its own provider cannot be used twice in one configuration.
- **A module states a version range; an example commits its lock file.** A module that pins a provider decides for every caller and cannot be composed with another module that pinned differently. An example's `versions.tf` also states a range, and its committed `.terraform.lock.hcl` records the exact provider version and hashes it was tested with. `make clean` leaves those lock files alone.
- **Key collections by name, not position.** Use `for_each` over a map. `count` renumbers everything after a removal, which turns one deletion into a rebuild.
- **The keys of a `for_each` must be known at plan.** A map of static names whose values come from other resources is fine. A set built from those values is not, because its keys *are* the values and they do not exist until apply. `toset(var.subnet_ids)` fails the first plan of any stack that creates its subnets; `var.subnet_ids` as a map keyed by zone does not.
- **Decide whether a resource exists with a bool or an object, never by whether a string is null.** Terraform cannot tell that a value from another resource is not null until apply, so `count = var.policy_json == null ? 0 : 1` fails exactly when the policy names something in the same plan. Use `attach_policy = true`, or wrap the value in an object whose nullness is known.
- **Never make two differently shaped objects share a type.** A conditional between object literals with different attributes fails to evaluate, and `merge()` or `concat()` across them turns numbers into strings. Where a JSON document varies in shape, encode each variant on its own and choose between the strings.
- **Validate what you can at plan time**, with a `validation` block on a variable, or a `precondition` where the check spans several inputs. Failing at plan costs seconds; failing at apply can leave half a stack behind.
- **Describe every input and output.** The description is the documentation, and the README tables are generated from it.
- **Mark sensitive inputs `sensitive`** so they stay out of plan output and CI logs.
- **Secure defaults, with a variable to choose otherwise.** Encryption on, public addresses off, logging on.

## Policy

`make policy` checks the conventions a machine can decide with [conftest](https://www.conftest.dev/). [`policy/README.md`](policy/README.md) lists the rules.

**A new rule needs a fixture.** `policy/tests/fixture` holds one small module per rule, each breaking exactly one convention, and the lane checks that every rule still refuses its fixture before it reports the repository clean. Name the fixture files `*.tf.fixture`: they are broken Terraform on purpose, and under a `.tf` name other scanners report them as real findings.

## Comments

A comment says what the code does or what it guards against, in a sentence or two. The reason a change was made goes in the commit message; what a user of the module would notice goes in the changelog.

## Changelog

Add an entry under `## [Unreleased]` in `CHANGELOG.md` as part of the change. Say what someone using the module would notice, and for a breaking change, what they have to do. If the heading is not there, add it above the latest release.

## Releasing

People use these modules by tag, so a change is not reachable until it is released. Move the `## [Unreleased]` entries under a new version heading, add the link definition at the bottom of the file, then tag:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z
```

The tag starts the release workflow, which checks the changelog has a section for that version and publishes it as the release notes.
