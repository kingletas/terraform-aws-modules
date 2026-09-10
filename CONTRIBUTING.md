# Contributing

## Before you open a pull request

```bash
make check
```

Everything has to pass. If a lane cannot run because a tool is missing, `make check` says so and exits non-zero — install the tool rather than working around the message.

## Adding a module

A module goes in `modules/<name>/` with these files:

| File | Holds |
|---|---|
| `versions.tf` | `required_version` and `required_providers`, and nothing else |
| `variables.tf` | Every input, each with a type and a description |
| `main.tf` | Resources. Split into further files when one gets long |
| `outputs.tf` | Every output, each with a description |
| `README.md` | Prose, plus the generated tables between the `TF_DOCS` markers |

Then add an example under `examples/` that actually uses it, with a plan test in `examples/<name>/tests/plan.tftest.hcl`. A module nothing composes is a module nobody has run — and `terraform validate` alone will not tell you it works, because it runs with every variable unknown. `make plan-test` evaluates every example with real values against mock providers, and it is the check that finds the rules above being broken.

If a plan test needs a value only AWS would know — a certificate's validation records, a realistic ARN — state it with an `override_resource` and `override_during = plan`. Shared mock values live in `testing/mocks/`.

## What the modules agree on

Follow these so the next module behaves like the last one:

- **No `provider` blocks in a module.** Declare requirements; let the caller configure. A module carrying its own provider cannot be instantiated twice.
- **Version constraints are ranges in modules and exact pins in examples.** A library says what it tolerates; a deployment says what it was tested against.
- **Key collections by name, not position.** Use `for_each` over a map. `count` renumbers everything after a removal, which turns a deletion into a rebuild.
- **The keys of a `for_each` must be known at plan.** A map of static names whose values come from other resources is fine; a set built from those values is not, because its keys *are* the values and they do not exist until apply. `toset(var.subnet_ids)` fails the first plan of any stack that creates its subnets; `var.subnet_ids` as a map keyed by zone does not.
- **Decide whether a resource exists with a bool or an object, never by whether a string is null.** Terraform cannot tell that a value from another resource is not null until apply, so `count = var.policy_json == null ? 0 : 1` fails exactly when the policy names something in the same plan. Use `attach_policy = true`, or wrap the value in an object whose nullness is known.
- **Never make two differently shaped objects share a type.** A conditional between object literals with different attributes fails to evaluate, and `merge()` or `concat()` across them silently turns numbers into strings. Where a JSON document varies in shape, encode each variant on its own and choose between the strings.
- **Validate what you can at plan time.** A `validation` block on a variable, or a `precondition` where the check spans several inputs. Failing at plan costs seconds; failing at apply can leave half a stack behind.
- **Describe every input and output.** The description is the documentation; the tables are generated from it.
- **Mark sensitive inputs `sensitive`** so they stay out of plan output and CI logs.
- **Secure defaults, with a variable to choose otherwise.** Encryption on, public addresses off, logging on.

## Comments

A comment says what the code does or what it guards against, in a sentence or two. The reason a change was made goes in the commit message; what a user of the module would notice goes in the changelog.

## Changelog

Add an entry under `## [Unreleased]` as part of the change, not afterwards. Say what someone using the module would notice.

## Releasing

Modules are consumed by tag, so a release is what makes a change reachable:

```bash
git tag -a v0.2.0 -m "Add the rds module" && git push origin v0.2.0
```

Move the `## [Unreleased]` entries under the new version heading first.
