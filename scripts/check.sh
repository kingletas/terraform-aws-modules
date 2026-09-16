#!/usr/bin/env bash
# Every gate a commit has to pass. A lane whose tool is absent is reported, never skipped silently.
# shellcheck source=scripts/lib.sh
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

failed=()
unrun=()

run_lane() {
  local name="$1"
  shift

  say "$name"
  "$@"
  local status=$?

  case $status in
    0) ;;
    127) unrun+=("$name") ;;
    *) failed+=("$name") ;;
  esac
}

run_lane "format" "$TERRAFORM" fmt -check -recursive -diff "$ROOT_DIR"
run_lane "validate" "$ROOT_DIR/scripts/validate.sh"
run_lane "plan" "$ROOT_DIR/scripts/plan.sh"
run_lane "lint" "$ROOT_DIR/scripts/lint.sh"
run_lane "security" "$ROOT_DIR/scripts/security.sh"
run_lane "policy" "$ROOT_DIR/scripts/policy.sh"
run_lane "docs" env CHECK_ONLY=1 "$ROOT_DIR/scripts/docs.sh"

echo
if [[ ${#unrun[@]} -gt 0 ]]; then
  bad "not run, tool missing: ${unrun[*]}"
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  bad "failed: ${failed[*]}"
  exit 1
fi

if [[ ${#unrun[@]} -gt 0 ]]; then
  bad "some lanes could not run; this is not a pass"
  exit 2
fi

ok "all lanes passed"
