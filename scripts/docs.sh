#!/usr/bin/env bash
# Regenerate each module README's tables, or with CHECK_ONLY=1 fail if any is stale.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_tool "$TERRAFORM_DOCS" terraform-docs || exit $?

check=()
[[ "${CHECK_ONLY:-0}" == "1" ]] && check=(--output-check)

failed=0
for dir in "$ROOT_DIR"/modules/*/; do
  name="modules/$(basename "$dir")"
  # terraform-docs says whether the README is stale or its own config is broken;
  # both fail, and only its output tells them apart.
  if output="$("$TERRAFORM_DOCS" --config "$ROOT_DIR/.terraform-docs.yml" "${check[@]}" "$dir" 2>&1)"; then
    ok "$name"
  else
    bad "$name"
    printf '%s\n' "$output" | sed 's/^/      /' >&2
    failed=$((failed + 1))
  fi
done

[[ $failed -eq 0 ]] || exit 1
