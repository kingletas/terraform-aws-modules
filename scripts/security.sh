#!/usr/bin/env bash
# Run checkov over the repository, using the skip list in .checkov.yml.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_tool "$CHECKOV" checkov || exit $?

"$CHECKOV" --directory "$ROOT_DIR" --config-file "$ROOT_DIR/.checkov.yml"
