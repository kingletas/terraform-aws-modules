#!/usr/bin/env bash
# Remove Terraform working directories. Lock files in examples are kept, since they are committed.
# shellcheck source=scripts/lib.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

find "$ROOT_DIR" -type d -name '.terraform' -prune -print -exec rm -rf {} +
find "$ROOT_DIR/modules" -name '.terraform.lock.hcl' -print -delete
