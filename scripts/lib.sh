#!/usr/bin/env bash
# Shared helpers for the check scripts. Sourced, never executed.

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TERRAFORM="${TERRAFORM:-terraform}"
CHECKOV="${CHECKOV:-checkov}"
TFLINT="${TFLINT:-tflint}"
TERRAFORM_DOCS="${TERRAFORM_DOCS:-terraform-docs}"

# One provider download shared by every directory, in a cache of this checkout's
# own so no other project can corrupt it. Terraform ignores a cache where there
# is no lock file, which is every module, unless told otherwise.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$ROOT_DIR/local.d/plugin-cache}"
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE="${TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE:-true}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"


# Every directory holding a root or child module, in a stable order.
terraform_dirs() {
  find "$ROOT_DIR/modules" "$ROOT_DIR/examples" -mindepth 1 -maxdepth 1 -type d | sort
}

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$*"; }
bad() { printf '    \033[31m✗\033[0m %s\n' "$*" >&2; }

# The version .tool-versions pins for a tool. CI reads the same file.
pinned_version() {
  awk -v tool="$1" '$1 == tool { print $2 }' "$ROOT_DIR/.tool-versions"
}

# Refuses a missing tool, a placeholder, or a version whose output would differ
# from what the repository was checked with. Returns 127 for "not run".
require_tool() {
  local command="$1" name="$2" want got
  want="$(pinned_version "$name")"

  if ! command -v "$command" >/dev/null 2>&1; then
    bad "$name is not installed — this lane did not run (this repository expects $want)"
    return 127
  fi

  got="$("$command" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  if [[ -z "$got" ]]; then
    bad "$name on PATH is a placeholder, not the real tool — this lane did not run"
    return 127
  fi

  if [[ "$got" != "$want" ]]; then
    bad "$name $got is installed; this repository expects $want, and the two produce different output"
    return 2
  fi
}
