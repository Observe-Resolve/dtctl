#!/usr/bin/env bash
# Render every dtctl manifest with ${APP_VERSION} substituted in.
# Emits a single YAML stream to stdout so you can pipe straight to `dtctl apply -f -`.
#
# Usage:
#   APP_VERSION=v1.1.0 ./scripts/stamp-version.sh > rendered.yaml
#   APP_VERSION=v1.1.0 ./scripts/stamp-version.sh | dtctl apply -f -
set -euo pipefail

: "${APP_VERSION:?APP_VERSION must be set (e.g. v1.1.0 or v0.0.0-dev)}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTCTL_DIR="$REPO_ROOT/dtctl"

# envsubst will expand ${APP_VERSION} and leave every other ${…} alone
export APP_VERSION

first=1
# Preserve the order we show on camera: dashboards → SLOs → workflows → guardians → lookups
for dir in dashboards slos workflows guardians; do
  for f in "$DTCTL_DIR/$dir"/*.yaml; do
    [[ -e "$f" ]] || continue
    if [[ $first -eq 0 ]]; then printf '\n---\n'; fi
    first=0
    envsubst '${APP_VERSION}' < "$f"
  done
done

# CSV lookups aren't templated — echo them at the end as a separator block so
# `dtctl apply -f -` handles them in the same stream if supported, otherwise
# scripts can split on the `# +lookup:` marker.
for csv in "$DTCTL_DIR/lookups"/*.csv; do
  [[ -e "$csv" ]] || continue
  printf '\n---\n# +lookup: %s\n' "$(basename "$csv")"
  cat "$csv"
done
