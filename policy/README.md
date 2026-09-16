# Policy

The conventions in [CONTRIBUTING.md](../CONTRIBUTING.md), as rules a machine decides. Run with `make policy`, and as a lane of `make check`.

```bash
make policy
```

## What this decides, and what checkov and tflint already decide

checkov and tflint judge **the infrastructure these modules build**: whether a bucket is public, whether a volume is encrypted, whether a variable has a description. Both do that well and neither is repeated here.

These rules judge **the code**. They are the conventions that make a module composable and a plan stable, every one of which could previously be broken with a green build:

| Rule | What it costs when it is broken |
|---|---|
| A module carries no `provider` block | A module with its own provider cannot be used twice in one configuration |
| Every required provider states a version | The build floats, and two checkouts resolve differently |
| A module states a range, not a pin | A library that pins decides for every caller, and two pinned modules cannot be composed |
| `count` is not set to a length | `count` renumbers every element after a removal, so deleting one rebuilds the rest |
| Existence is not decided by a null string | Terraform cannot know a value from another resource is non-null until apply, so the plan fails exactly when the value comes from the same plan |
| A credential-shaped string is `sensitive` | An unmarked value is printed in plan output and in CI logs |
| Every module has `versions.tf`, `variables.tf`, `outputs.tf` | A reader has to search for what should be in the same three places every time |

## Every rule is proved to still refuse

`tests/fixture` holds one small module per rule, each breaking exactly one convention. `make policy` runs the repository first, which must be silent, then every fixture, each of which must produce **exactly one** finding, and that finding must be the right one.

That second half is the point. A rule that has never been watched refuse decides nothing, and a rule that quietly stops matching looks identical to a repository that is clean. Both halves run every time.

A fixture is copied under `modules/` before it is checked, because several rules key on that prefix, and a fixture checked anywhere else would prove nothing.

**Fixtures are stored as `*.tf.fixture` and take the `.tf` name only inside that copy.** They are deliberately broken Terraform, and under a real `.tf` name every infrastructure scanner treats them as real findings: `trivy` refused a commit over an unencrypted bucket in a fixture whose entire job was to omit `outputs.tf`. conftest is told its parser explicitly, so the extension costs it nothing. The alternative was a path exclusion in each scanner, which means a new exclusion every time a scanner is added and a fixture that is one forgotten config line away from failing every commit.

## What this deliberately does not decide

**`toset()` in a `for_each`.** `CONTRIBUTING.md` warns that `toset(var.subnet_ids)` fails the first plan of any stack that creates its own subnets, because the keys of the set *are* the values and they do not exist until apply. That is true and it matters.

It is not a rule here, because `toset()` appears eleven times in this repository and most of them are fine: service names, availability zones and account IDs are all known at plan. Nothing in the source says which values arrive from another resource. A rule that fired on all eleven would be wrong nine times, and a check that is wrong most of the time is one people learn to scroll past. It stays in review, named rather than implied.

**Whether a module is used anywhere.** A module with no example and no test of its own is a real gap, and it is a question about the whole tree rather than about any file. `make plan-test` already fails when a module has neither.

## Adding a rule

Write the rule in `conventions.rego`, then write the fixture that proves it refuses, then run `make policy`. **A rule without a fixture is not finished**, and the runner will not tell you so, because it only checks the fixtures that exist.

Check the rule against the whole repository before committing it. The first draft of these seven produced 34 findings and every one was a false positive: `length(x) > 0 ? 1 : 0` read as a collection keyed by position, and `manage_master_password`, a bool, read as a credential. A rule that fires when nothing is wrong is worse than no rule, because it teaches you to ignore the lane.
