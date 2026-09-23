#!/usr/bin/env bash
#
# Prove what upgrading from the previous release does to live resources, against MiniStack.
#
# Applies from.tf.fixture from a checkout of the previous release, then plans and applies
# to.tf.fixture from this checkout over the same state, three ways:
#
#   replace   no preparation: every address in moves.tsv is destroyed and created again
#   moved     a moved block per line of moves.tsv: every resource is kept
#   state-mv  terraform state mv per line of moves.tsv before the plan: every resource is kept
#
# Anything else in the plan must be an update, never a replacement. moves.tsv holds one
# "old<TAB>new" address pair per line, with @RUN@ standing for the run's name prefix.
#
# MiniStack does not store every attribute it is given, so some resources never settle even
# with no upgrade at all. A plan of the old shape straight after its apply finds those changes,
# and the same change on the same resource is left out of every count and reported by number.
#
# Usage:
#   UPGRADE_ENDPOINT=http://127.0.0.1:14580 testing/upgrade/run.sh [replace|moved|state-mv|all]
#
# Environment overrides:
#   UPGRADE_ENDPOINT  MiniStack URL; refused unless it is a local address (required)
#   UPGRADE_FROM      the git ref of the previous release (default: the newest v* tag)
#
# Nothing here can reach real AWS: the credentials are the literal string "test" and every
# endpoint is redirected to the emulator. Work happens under local.d/ and is removed on exit.

set -euo pipefail

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { sed -n '2,/^set -/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FROM="${UPGRADE_FROM:-$(git -C "$ROOT" tag --list 'v*' --sort=-version:refname | head -n 1)}"
ENDPOINT="${UPGRADE_ENDPOINT:-}"
WORK="$ROOT/local.d/upgrade"

LOCAL_HOSTS=" localhost 127.0.0.1 ::1 172.17.0.1 ministack "

[[ -n "$ENDPOINT" ]] || { echo "set UPGRADE_ENDPOINT to a local MiniStack, for example http://127.0.0.1:14580" >&2; exit 2; }
[[ -n "$FROM" ]] || { echo "no previous release found; set UPGRADE_FROM" >&2; exit 2; }

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
trap 'git -C "$ROOT" worktree remove --force "$OLD" >/dev/null 2>&1 || true; rm -rf "$(dirname "$OLD")"' EXIT

mkdir -p "$WORK/plugins"
git -C "$ROOT" worktree add --detach --quiet "$OLD" "$FROM"

# The old checkout may predate these fixtures, so both sides read them from here.
stage() {
  local dir="$1" fixture="$2" state="$3"
  rm -rf "$dir"
  mkdir -p "$dir"
  cp "$HERE/$fixture.tf.fixture" "$dir/main.tf"
  printf 'terraform {\n  backend "local" {}\n}\n' > "$dir/backend.tf"
  terraform -chdir="$dir" init -backend-config="path=$state" -no-color >/dev/null
}

# Addresses a saved plan changes, one "action<TAB>address" per line.
changes() {
  terraform -chdir="$1" show -json "$2" | python3 -c '
import json, sys
for change in json.load(sys.stdin).get("resource_changes", []):
    actions = change["change"]["actions"]
    for action in ("create", "delete", "update"):
        if action in actions:
            print(action, change["address"], sep="\t")
'
}

# Compares a plan against moves.tsv, leaving out what MiniStack never settles.
judge() {
  python3 - "$@" <<'PY'
import sys
scenario, moves_path, drift_path, plan_path, label = sys.argv[1:6]
moves = [line.rstrip("\n").split("\t") for line in open(moves_path) if line.strip()]
new_of = dict(moves)
drift = {tuple(line.rstrip("\n").split("\t")) for line in open(drift_path) if line.strip()}
drift_count = len(drift)
drift |= {(action, new_of.get(address, address)) for action, address in drift}
drifted = {address for action, address in drift if action != "update"}
changes = [tuple(line.rstrip("\n").split("\t")) for line in open(plan_path) if line.strip()]
counted = [change for change in changes if change not in drift]
created = {address for action, address in counted if action == "create"}
deleted = {address for action, address in counted if action == "delete"}
updated = {address for action, address in counted if action == "update"}
if label == "plan" and scenario == "replace":
    want_created = {new for old, new in moves if old not in drifted}
    want_deleted = {old for old, new in moves if old not in drifted}
else:
    want_created, want_deleted = set(), set()
print(f"{label}: {len(created)} created, {len(deleted)} destroyed, {len(updated)} updated;"
      f" {drift_count} changes MiniStack makes with no upgrade at all left out")
for address in sorted(created ^ want_created) + sorted(deleted ^ want_deleted):
    print(f"  unexpected: {address}", file=sys.stderr)
sys.exit(0 if created == want_created and deleted == want_deleted else 1)
PY
}

prove() {
  local scenario="$1"
  local run old_dir new_dir state vars moves verdict=0
  run="upg-${scenario//-/}-$(printf '%04d' $((RANDOM % 10000)))"
  old_dir="$OLD/local.d/upgrade-$scenario"
  new_dir="$ROOT/local.d/upgrade-$scenario"
  state="$WORK/$scenario.tfstate"
  moves="$WORK/$scenario-moves.tsv"
  vars=(-var "run=$run")
  rm -f "$state"
  sed "s/@RUN@/$run/g" "$HERE/moves.tsv" > "$moves"

  stage "$old_dir" from "$state"
  terraform -chdir="$old_dir" apply -auto-approve -no-color "${vars[@]}" >"$WORK/$scenario-before.log"
  terraform -chdir="$old_dir" plan -out=control.out -no-color "${vars[@]}" >"$WORK/$scenario-control.log"
  changes "$old_dir" control.out > "$WORK/$scenario-drift.tsv"

  stage "$new_dir" to "$state"
  case "$scenario" in
    moved)
      while IFS=$'\t' read -r from to; do
        printf 'moved {\n  from = %s\n  to   = %s\n}\n\n' "$from" "$to"
      done < "$moves" > "$new_dir/moved.tf"
      ;;
    state-mv)
      while IFS=$'\t' read -r from to; do
        terraform -chdir="$new_dir" state mv "$from" "$to" >/dev/null
      done < "$moves"
      ;;
  esac

  terraform -chdir="$new_dir" plan -out=plan.out -no-color "${vars[@]}" >"$WORK/$scenario-plan.log"
  changes "$new_dir" plan.out > "$WORK/$scenario-plan.tsv"
  printf '%-9s ' "$scenario"
  judge "$scenario" "$moves" "$WORK/$scenario-drift.tsv" "$WORK/$scenario-plan.tsv" plan || verdict=1

  if terraform -chdir="$new_dir" apply -auto-approve -no-color plan.out >"$WORK/$scenario-apply.log" 2>&1; then
    terraform -chdir="$new_dir" plan -out=replan.out -no-color "${vars[@]}" >"$WORK/$scenario-replan.log"
    changes "$new_dir" replan.out > "$WORK/$scenario-replan.tsv"
    printf '%-9s ' ""
    judge "$scenario" "$moves" "$WORK/$scenario-drift.tsv" "$WORK/$scenario-replan.tsv" "after apply" || verdict=1
  else
    echo "$scenario: the apply failed; see $WORK/$scenario-apply.log" >&2
    verdict=1
  fi

  # A write-only value must never reach state, whatever else the upgrade did.
  if grep -q -- "$run-second" "$state"; then
    echo "$scenario: the write-only secret value is in the state file" >&2
    verdict=1
  fi

  terraform -chdir="$new_dir" destroy -auto-approve -no-color "${vars[@]}" >"$WORK/$scenario-destroy.log" 2>&1 \
    || echo "$scenario: destroy failed; restart MiniStack to clear it" >&2
  rm -rf "$old_dir" "$new_dir"
  return "$verdict"
}

status=0
case "${1:-all}" in
  all) for scenario in replace moved state-mv; do prove "$scenario" || status=1; done ;;
  replace | moved | state-mv) prove "$1" || status=1 ;;
  *) echo "usage: run.sh [replace|moved|state-mv|all]" >&2; exit 2 ;;
esac
exit "$status"
