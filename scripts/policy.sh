#!/usr/bin/env bash
# Check the repository against the conventions in CONTRIBUTING.md, then check
# that every rule still refuses the thing it was written to refuse.
#
# Usage: policy.sh [-q]
#   -q  say nothing when everything passes, for a commit hook. Failures always print.
# shellcheck source=scripts/lib.sh
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

quiet=0
while getopts ":q" opt; do
  case "$opt" in
    q) quiet=1 ;;
    *) printf 'usage: %s [-q]\n' "${BASH_SOURCE[0]##*/}" >&2; exit 2 ;;
  esac
done

# A passing lane on an ordinary commit should be silent. A failing one never is.
pass() { [[ $quiet -eq 1 ]] || ok "$@"; }

require_tool "$CONFTEST" conftest || exit $?

policy_dir="$ROOT_DIR/policy"
fixture_dir="$policy_dir/tests/fixture"

conftest_run() {
  "$CONFTEST" test \
    --policy "$policy_dir" \
    --parser hcl2 \
    --combine \
    --all-namespaces \
    --no-color \
    "$@"
}

failed=0

# --- the repository itself ---

mapfile -t sources < <(cd "$ROOT_DIR" && find modules examples -name '*.tf' -not -path '*/.terraform/*' | sort)

if (cd "$ROOT_DIR" && conftest_run "${sources[@]}" >/dev/null); then
  pass "modules and examples"
else
  bad "modules and examples"
  (cd "$ROOT_DIR" && conftest_run "${sources[@]}" | grep '^FAIL' >&2)
  failed=$((failed + 1))
fi

# --- and every rule, against the thing it exists to refuse ---
#
# A fixture is copied under modules/ before it runs, because several rules key
# on that prefix and a fixture checked anywhere else would prove nothing. Each
# one breaks exactly one convention, so exactly one finding is the pass.
#
# Fixtures are stored as *.tf.fixture and take the .tf name only here. They are
# deliberately broken Terraform, and under a .tf name trivy and tflint report
# them as real findings.

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

for dir in "$fixture_dir"/*/; do
  name="$(basename "$dir")"
  expected="$(head -1 "$dir/EXPECT")"

  mkdir -p "$staging/modules/$name"
  for source in "$dir"*.tf.fixture; do
    cp "$source" "$staging/modules/$name/$(basename "$source" .fixture)"
  done

  output="$(cd "$staging" && conftest_run "modules/$name"/*.tf 2>&1)"
  findings="$(grep -c '^FAIL' <<<"$output")"

  if [[ "$findings" -ne 1 ]]; then
    bad "$name produced $findings findings, expected exactly 1"
    grep '^FAIL' <<<"$output" >&2
    failed=$((failed + 1))
  elif grep -qF -- "$expected" <<<"$output"; then
    pass "$name refused"
  else
    bad "$name was refused for the wrong reason"
    printf '    expected: %s\n' "$expected" >&2
    grep '^FAIL' <<<"$output" >&2
    failed=$((failed + 1))
  fi
done

[[ $failed -eq 0 ]] || exit 1
