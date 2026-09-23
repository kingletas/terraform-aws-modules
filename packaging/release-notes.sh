#!/usr/bin/env bash
#
# release-notes.sh -- print one version's section of the CHANGELOG.
#
# Usage:
#   packaging/release-notes.sh 0.1.1
#
# Environment overrides:
#   CHANGELOG   the file to read (default: CHANGELOG.md at the root of this repository)
#
# The release body on GitHub is the changelog entry, not a second description
# written by hand: two accounts of the same release drift, and the one nobody
# reads while writing is the one that goes stale.
#
# Exits 1 when the version has no section, so a release cannot ship with an
# empty body, and when a patch version's section lists breaking changes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
CHANGELOG="${CHANGELOG:-$HERE/CHANGELOG.md}"

[ -n "$VERSION" ] || { echo "usage: release-notes.sh VERSION" >&2; exit 2; }

# Everything between this version's heading and the next one at the same level.
# This changelog is Keep a Changelog, so a heading reads "## [0.2.0] - 2026-09-15".
# The second field has its brackets and any colon stripped before comparing,
# which also accepts a plain "## 0.2.0". The compare is a string one, so a dot
# in the version cannot stand in for any other character.
notes="$(awk -v version="$VERSION" '
  function bare(f) { gsub(/\[/, "", f); gsub(/\]/, "", f); gsub(/:/, "", f); return f }
  !found && $1 == "##" && bare($2) == version { found = 1; next }
  found && $1 == "##" { exit }
  found { print }
' "$CHANGELOG")"

# The link definitions at the foot of the file sit inside the last version's
# section, because nothing below them starts a new heading. They are markdown
# plumbing rather than notes, and the oldest release is the one that gets them.
# Held back until real content follows, so a definition mid-section survives and
# a trailing block does not.
notes="$(printf '%s\n' "$notes" | awk '
  /^\[[^]]+\]:[[:space:]]/ { held = held $0 "\n"; next }
  /^[[:space:]]*$/ { held = held $0 "\n"; next }
  { printf "%s", held; held = ""; print }
')"

# Trim the blank lines the heading boundaries leave behind.
notes="$(printf '%s\n' "$notes" | sed -e '/./,$!d' -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [ -z "$notes" ]; then
  echo "release-notes.sh: no section for $VERSION in $CHANGELOG" >&2
  exit 1
fi

# A patch release promises nothing a caller wrote has to change, so breaking changes need at least a minor bump.
patch="${VERSION##*.}"
if [ "$patch" != "0" ] && printf '%s\n' "$notes" | grep -qiE '^#+[[:space:]]*breaking'; then
  echo "release-notes.sh: $VERSION is a patch release but its section lists breaking changes; release it as a minor version" >&2
  exit 1
fi

printf '%s\n' "$notes"
