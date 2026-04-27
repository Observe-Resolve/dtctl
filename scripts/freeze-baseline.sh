#!/usr/bin/env bash
# Freeze the current weaver/registry/ as the new weaver/baselines/main/.
# Called by release.yml on a `pass` verdict so the next PR's registry diff is comparing
# against what shipped in the latest release, not against arbitrary intermediate state.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/weaver/registry"
DST="$REPO_ROOT/weaver/baselines/main"

log() { printf '\033[1;32m[baseline]\033[0m %s\n' "$*" >&2; }

log "freezing $SRC -> $DST"

# Only copy YAML files; keep the README.md in $DST untouched.
mkdir -p "$DST"
find "$DST" -type f -name '*.yaml' -delete
cp -R "$SRC"/*.yaml "$DST/"

log "done. Run: git add weaver/baselines/main && git commit -m 'chore(weaver): freeze baseline'"
