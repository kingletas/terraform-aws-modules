#!/usr/bin/env bash
#
# Prove what upgrading from the previous release does to live resources, against MiniStack.
#
# Applies testing/upgrade/<from>.tf.fixture from a checkout of the previous tag, then plans
# and applies <to>.tf.fixture from this checkout with the same state, three ways:
#
#   replace   no preparation: the rekeyed resources are destroyed and created again
#   moved     moved.tf.fixture added: every resource is kept
#   state-mv  terraform state mv before the plan: every resource is kept
#
# Usage:
#   UPGRADE_ENDPOINT=http://127.0.0.1:14580 testing/upgrade/run.sh [replace|moved|state-mv|all]
#
# Environment overrides:
#   UPGRADE_ENDPOINT  MiniStack URL; refused unless it is a local address (required)
#   UPGRADE_FROM      the release to upgrade from (default v0.5.0)
#   UPGRADE_TO        the fixture this checkout is proved with (default 0.6.0)
#
# Nothing here can reach real AWS: the credentials are the literal string "test" and every
# endpoint is redirected to the emulator. Work happens under local.d/ and is removed on exit.

set -euo pipefail

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { sed -n '2,/^set -/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FROM="${UPGRADE_FROM:-v0.5.0}"
TO="${UPGRADE_TO:-0.6.0}"
ENDPOINT="${UPGRADE_ENDPOINT:-}"
WORK="$ROOT/local.d/upgrade"

LOCAL_HOSTS=" localhost 127.0.0.1 ::1 172.17.0.1 ministack "

[[ -n "$ENDPOINT" ]] || { echo "set UPGRADE_ENDPOINT to a local MiniStack, for example http://127.0.0.1:14580" >&2; exit 2; }

host="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname or "")' "$ENDPOINT")"
if [[ "$LOCAL_HOSTS" != *" $host "* ]]; then
  echo "refusing non-local AWS endpoint $ENDPOINT" >&2
  exit 1
fi

python3 - "$ENDPOINT/_ministack/health" <<'PY' || { echo "MiniStack is not answering at $ENDPOINT" >&2; exit 1; }
import sys, urllib.request
with urllib.request.urlopen(sys.argv[1], timeout=5) as response:
    sys.exit(0 if response.status == 200 else 1)
PY

unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_ROLE_ARN AWS_WEB_IDENTITY_TOKEN_FILE
unset AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
export AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_SESSION_TOKEN=test
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
export AWS_SKIP_CREDENTIALS_VALIDATION=true AWS_SKIP_REQUESTING_ACCOUNT_ID=true
export AWS_ENDPOINT_URL="$ENDPOINT" AWS_S3_USE_PATH_STYLE=true
export TF_IN_AUTOMATION=1 TF_INPUT=0
export TF_PLUGIN_CACHE_DIR="$WORK/plugins"

OLD="$(mktemp -d)/checkout"
cleanup() {
  git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true
  rm -rf "$(dirname "$OLD")"
}
trap cleanup EXIT

mkdir -p "$WORK/plugins"
git -C "$ROOT" worktree add --detach --quiet "$OLD" "$FROM"

# The old checkout has no copy of the fixtures, so both sides read them from here.
stage() {
  local dir="$1" fixture="$2" state="$3"
  rm -rf "$dir"
  mkdir -p "$dir"
  cp "$HERE/$fixture.tf.fixture" "$dir/main.tf"
  printf 'terraform {\n  backend "local" {}\n}\n' > "$dir/backend.tf"
  terraform -chdir="$dir" init -backend-config="path=$state" -no-color >/dev/null
}

# Prints how many resources the saved plan creates, destroys, updates and moves.
count_actions() {
  terraform -chdir="$1" show -json plan.out | python3 -c '
import json, sys
plan = json.load(sys.stdin)
counts = {"create": 0, "delete": 0, "update": 0, "moved": 0}
for change in plan.get("resource_changes", []):
    actions = change["change"]["actions"]
    for action in ("create", "delete", "update"):
        if action in actions:
            counts[action] += 1
    if change.get("previous_address"):
        counts["moved"] += 1
print(counts["create"], counts["delete"], counts["update"], counts["moved"])
'
}

prove() {
  local scenario="$1"
  local run old_dir new_dir state vars create delete update moved want_create
  run="upg-${scenario//-/}-$(printf '%04d' $((RANDOM % 10000)))"
  old_dir="$OLD/local.d/upgrade-$scenario"
  new_dir="$ROOT/local.d/upgrade-$scenario"
  state="$WORK/$scenario.tfstate"
  vars=(-var "run=$run")
  rm -f "$state"

  stage "$old_dir" "${FROM#v}" "$state"
  terraform -chdir="$old_dir" apply -auto-approve -no-color "${vars[@]}" >"$WORK/$scenario-before.log"

  stage "$new_dir" "$TO" "$state"
  case "$scenario" in
    moved) sed "s/@RUN@/$run/g" "$HERE/moved.tf.fixture" > "$new_dir/moved.tf" ;;
    state-mv)
      terraform -chdir="$new_dir" state mv "module.parameters.aws_ssm_parameter.this[\"/$run/api/log-level\"]" 'module.parameters.aws_ssm_parameter.this["log-level"]' >/dev/null
      terraform -chdir="$new_dir" state mv "module.key.aws_kms_alias.extra[\"$run-legacy\"]" 'module.key.aws_kms_alias.extra["legacy"]' >/dev/null
      ;;
  esac

  terraform -chdir="$new_dir" plan -out=plan.out -no-color "${vars[@]}" >"$WORK/$scenario-plan.log"
  read -r create delete update moved < <(count_actions "$new_dir")
  local applied=yes settled=no
  terraform -chdir="$new_dir" apply -auto-approve -no-color plan.out >"$WORK/$scenario-apply.log" 2>&1 || applied=no
  if [[ "$applied" == yes ]]; then
    terraform -chdir="$new_dir" plan -detailed-exitcode -no-color "${vars[@]}" >"$WORK/$scenario-replan.log" 2>&1 && settled=yes
  fi
  terraform -chdir="$new_dir" destroy -auto-approve -no-color "${vars[@]}" >"$WORK/$scenario-destroy.log" 2>&1 \
    || echo "$scenario: destroy failed; restart MiniStack to clear it" >&2
  rm -rf "$old_dir" "$new_dir"

  printf '%-9s plan: %s to create, %s to destroy, %s to update, %s moved; applied: %s; settled afterwards: %s\n' \
    "$scenario" "$create" "$delete" "$update" "$moved" "$applied" "$settled"

  want_create=0
  [[ "$scenario" == replace ]] && want_create=2
  if [[ "$create" != "$want_create" || "$delete" != "$want_create" || "$applied" != yes || "$settled" != yes ]]; then
    echo "$scenario: expected $want_create created and $want_create destroyed, a clean apply and a settled plan; logs in $WORK" >&2
    return 1
  fi
}

case "${1:-all}" in
  all) for scenario in replace moved state-mv; do prove "$scenario"; done ;;
  replace | moved | state-mv) prove "$1" ;;
  *) echo "usage: run.sh [replace|moved|state-mv|all]" >&2; exit 2 ;;
esac
