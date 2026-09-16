#!/usr/bin/env bash
# Initialise and validate every module and example.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

failed=0

for dir in $(terraform_dirs); do
  name="${dir#"$ROOT_DIR"/}"
  if ! "$TERRAFORM" -chdir="$dir" init -backend=false -input=false -no-color >/dev/null; then
    bad "$name: init failed"
    failed=$((failed + 1))
    continue
  fi

  if "$TERRAFORM" -chdir="$dir" validate -no-color >/dev/null; then
    ok "$name"
  else
    bad "$name"
    "$TERRAFORM" -chdir="$dir" validate -no-color >&2 || true
    failed=$((failed + 1))
  fi
done

if [[ $failed -gt 0 ]]; then
  bad "$failed director$([[ $failed -eq 1 ]] && echo y || echo ies) failed validation"
  exit 1
fi
