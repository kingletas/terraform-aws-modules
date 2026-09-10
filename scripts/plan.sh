#!/usr/bin/env bash
# Plan every example, and every module that has its own test, against mock
# providers so each expression is evaluated with real values. terraform validate
# leaves variables unknown and cannot catch that.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Every example must have a plan test. A module needs one only when no example
# composes it, since an example's test already plans every module it calls.
targets=()
for dir in "$ROOT_DIR"/examples/*/; do targets+=("$dir"); done
for dir in "$ROOT_DIR"/modules/*/; do [[ -f "$dir/tests/plan.tftest.hcl" ]] && targets+=("$dir"); done

failed=0
for dir in "${targets[@]}"; do
  name="${dir#"$ROOT_DIR"/}"
  name="${name%/}"
  [[ -f "$dir/tests/plan.tftest.hcl" ]] || { bad "$name — has no plan test"; failed=$((failed + 1)); continue; }

  if ! "$TERRAFORM" -chdir="$dir" init -backend=false -input=false -no-color >/dev/null; then
    bad "$name — init failed"
    failed=$((failed + 1))
    continue
  fi

  if output="$("$TERRAFORM" -chdir="$dir" test -no-color 2>&1)"; then
    ok "$name"
  else
    bad "$name"
    printf '%s\n' "$output" | sed -n '/Error:/,/^$/p' | head -20 >&2
    failed=$((failed + 1))
  fi
done

[[ $failed -eq 0 ]] || exit 1
