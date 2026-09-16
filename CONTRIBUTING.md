# Contributing

## Before you open a pull request

```bash
make check
```

Everything has to pass. If a lane can't run because a tool is missing or the wrong version, `make check` says so and fails. Install the version in `.tool-versions` rather than working around the message.

## Adding a module

A module goes in `modules/<name>/` with these files:

| File | Holds |
|---|---|
| `versions.tf` | `required_version` and `required_providers`, and nothing else |
| `variables.tf` | Every input, each with a type and a description |
| `main.tf` | Resources. Split into further files when one gets long |
| `outputs.tf` | Every output, each with a description |
| `README.md` | Prose, plus the generated tables between the `TF_DOCS` markers |

Then prove it plans. Use it in an example under `examples/`, with a plan test in `examples/<name>/tests/plan.tftest.hcl`, or give the module a `tests/plan.tftest.hcl` of its own if no example fits. `terraform validate` alone won't tell you it works, because it runs with every variable unknown. `make plan-test` evaluates every example and module test with real values against mock providers, and it's the check that catches the rules below being broken.

If a plan test needs a value only AWS would know, like a certificate's validation records or a realistic ARN, state it with an `override_resource` and `override_during = plan`. Shared mock values live in `testing/mocks/`. Keep mock values plainly fake: a string shaped like a private key gets refused by secret scanners, even in a test.

## What the modules agree on

Follow these so the next module behaves like the last one:

- **No `provider` blocks in a module.** Declare what it needs and let the caller configure it. A module with its own provider can't be used twice.
- **A module states a version range; an example commits its lock file.** A library says what it tolerates, so a module that pins decides for every caller and cannot be composed with another that pinned differently. An example says what it was tested against, and `.terraform.lock.hcl` is where that is recorded, down to the provider hashes. The constraint in an example's `versions.tf` stays a range; `make clean` leaves those lock files alone for exactly this reason.
- **Key collections by name, not position.** Use `for_each` over a map. `count` renumbers everything after a removal, which turns one deletion into a rebuild.
- **The keys of a `for_each` must be known at plan.** A map of static names whose values come from other resources is fine. A set built from those values isn't, because its keys *are* the values and they don't exist until apply. `toset(var.subnet_ids)` fails the first plan of any stack that creates its subnets; `var.subnet_ids` as a map keyed by zone doesn't.
- **Decide whether a resource exists with a bool or an object, never by whether a string is null.** Terraform can't tell that a value from another resource isn't null until apply, so `count = var.policy_json == null ? 0 : 1` fails exactly when the policy names something in the same plan. Use `attach_policy = true`, or wrap the value in an object whose nullness is known.
- **Never make two differently shaped objects share a type.** A conditional between object literals with different attributes fails to evaluate, and `merge()` or `concat()` across them quietly turns numbers into strings. Where a JSON document varies in shape, encode each variant on its own and choose between the strings.
- **Validate what you can at plan time**, with a `validation` block on a variable, or a `precondition` where the check spans several inputs. Failing at plan costs seconds; failing at apply can leave half a stack behind.
- **Describe every input and output.** The description is the documentation, and the README tables are generated from it.
- **Mark sensitive inputs `sensitive`** so they stay out of plan output and CI logs.
- **Secure defaults, with a variable to choose otherwise.** Encryption on, public addresses off, logging on.

## Policy

`make policy` checks the conventions above with [conftest](https://www.conftest.dev/), so the ones a machine can decide are decided rather than remembered. [`policy/README.md`](policy/README.md) says which those are, which are deliberately left to review, and why.

**A new rule needs a fixture.** `policy/tests/fixture` holds one small module per rule, each breaking exactly one convention, and the lane checks that every rule still refuses its own fixture before it certifies the repository clean. A rule nobody has watched refuse decides nothing. Name the files `*.tf.fixture`: they are broken Terraform on purpose, and under a `.tf` name every scanner reports them as real findings.

## Comments

A comment says what the code does or what it guards against, in a sentence or two. The reason a change was made goes in the commit message; what a user of the module would notice goes in the changelog.

## Changelog

Add an entry under `## [Unreleased]` as part of the change, not afterwards. Say what someone using the module would notice. If the heading isn't there, add it above the latest release.

## Releasing

People use these modules by tag, so a change isn't reachable until it's released. Move the `## [Unreleased]` entries under the new version heading, then tag:

```bash
git tag -a v0.2.0 -m "Add the rds module" && git push origin v0.2.0
```

The tag starts the release workflow, which checks the changelog has a section for that version and publishes it as the release notes.
