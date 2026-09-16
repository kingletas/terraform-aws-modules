#!/usr/bin/env bash
# Run the plan tests of one module or example, with the same fake AWS
# credentials as the full check.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dir="${1:-}"
if [[ -z "$dir" ]]; then
  echo "Usage: make test DIR=modules/<name>   or   make test DIR=examples/<name>" >&2
  exit 2
fi

target="$ROOT_DIR/${dir%/}"
if [[ ! -f "$target/tests/plan.tftest.hcl" ]]; then
  bad "$dir has no tests/plan.tftest.hcl"
  exit 2
fi

"$TERRAFORM" -chdir="$target" init -backend=false -input=false -no-color >/dev/null
"$TERRAFORM" -chdir="$target" test -no-color
