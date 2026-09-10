#!/usr/bin/env bash
# Run tflint over every module and example.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_tool "$TFLINT" tflint || exit $?

"$TFLINT" --init --config="$ROOT_DIR/.tflint.hcl" >/dev/null

failed=0
for dir in $(terraform_dirs); do
  name="${dir#"$ROOT_DIR"/}"
  if "$TFLINT" --chdir="$dir" --config="$ROOT_DIR/.tflint.hcl" --format=compact --no-color; then
    ok "$name"
  else
    bad "$name"
    failed=$((failed + 1))
  fi
done

[[ $failed -eq 0 ]] || exit 1
