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

# NOTE: CSV lookups are NOT included in this output stream because dtctl apply
# doesn't support creating lookup tables from embedded CSV data.
# Lookup tables must be uploaded separately with:
#   dtctl create lookup -f dtctl/lookups/service-baselines.yaml
# The CI/release workflows handle this in a separate step before applying manifests.
#
# Uncomment the block below if you need to see the CSV content in the rendered output:
# for csv in "$DTCTL_DIR/lookups"/*.csv; do
#   [[ -e "$csv" ]] || continue
#   printf '\n---\n# +lookup: %s\n' "$(basename "$csv")"
#   cat "$csv"
# done
