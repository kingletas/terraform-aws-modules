# Policy

The conventions in [CONTRIBUTING.md](../CONTRIBUTING.md) that a machine can decide, written as [conftest](https://www.conftest.dev/) rules in `conventions.rego`. They run with `make policy`, and as one lane of `make check`.

```bash
make policy
```

## What the rules check

checkov and tflint judge the infrastructure the modules build: whether a bucket is public, whether a volume is encrypted, whether a variable has a description. These rules judge the module code itself, and none of them repeats a checkov or tflint check.

| Rule | What goes wrong when it is broken |
|---|---|
| A module carries no `provider` block | A module with its own provider cannot be used twice in one configuration |
| Every required provider states a version | The provider version floats, and two checkouts resolve differently |
| A module states a range, not a pin | A module that pins decides for every caller, and two pinned modules cannot be composed |
| `count` is not set to a length | `count` renumbers every element after a removal, so deleting one rebuilds the rest |
| Existence is not decided by a null string | Terraform cannot know a value from another resource is non-null until apply, so the plan fails exactly when the value comes from the same plan |
| A credential-shaped string variable is `sensitive` | An unmarked value is printed in plan output and in CI logs |
| Every module has `versions.tf`, `variables.tf` and `outputs.tf` | A reader has to search for what should always be in the same three places |

The provider-block, range and three-files rules apply only under `modules/`. The other rules apply to examples too.

## How each rule is tested

`tests/fixture` holds one small module per rule, each breaking exactly one convention, with an `EXPECT` file naming the finding it must produce. `make policy` checks the repository first, which must produce no findings, then each fixture, which must produce exactly one finding, and the one named in `EXPECT`. A rule that stops matching fails the lane instead of passing silently.

Each fixture is copied under a `modules/` path before it is checked, because several rules only apply there.

Fixture files are stored as `*.tf.fixture` and renamed to `.tf` only inside that temporary copy. They are deliberately broken Terraform, and under a `.tf` name scanners such as tflint and trivy would report them as real findings.

## What is left to review

`toset()` in a `for_each` is not a rule. It fails a first plan only when the set's values come from resources created in the same plan, and nothing in the source says where a value comes from. Reviewers check it against the convention in CONTRIBUTING.md.

## Adding a rule

1. Write the rule in `conventions.rego`.
2. Add a fixture directory under `tests/fixture/` that breaks only that convention, with its `*.tf.fixture` files and an `EXPECT` file holding a line from the expected message.
3. Run `make policy`. The repository must stay clean and the new fixture must be refused for the right reason.

Check the rule against the whole repository before committing it. A rule that fires on correct code teaches people to ignore the lane.
