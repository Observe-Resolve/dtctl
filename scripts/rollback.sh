#!/usr/bin/env bash
# Roll back to the previous semver tag on main.
# Called by release.yml when the Guardian returns `fail`.
set -euo pipefail

log() { printf '\033[1;33m[rollback]\033[0m %s\n' "$*" >&2; }

: "${APP_VERSION:?APP_VERSION must be set to the failing version}"

# Resolve the previous tag (second-latest semver tag on main)
PREV_TAG=$(git tag --list --sort=-v:refname 'v*.*.*' | sed -n '2p')
if [[ -z "$PREV_TAG" ]]; then
  log "no previous tag found — aborting"
  exit 1
fi
log "rolling deployment back to $PREV_TAG (from failing $APP_VERSION)"

# 1. Helm rollback to the previous release
helm rollback checkout --wait --timeout 5m

# 2. Re-stamp dtctl manifests at the previous version so dashboards/SLOs match
APP_VERSION="$PREV_TAG" ./scripts/stamp-version.sh | dtctl apply -f -

# 3. Mark the failing Guardian as rolled back
dtctl annotate guardian "checkout-release-${APP_VERSION}" \
    --tag "rolled-back-to=${PREV_TAG}" \
    --tag "rollback-ts=$(date -u +%FT%TZ)" || true

log "rollback complete. Dashboards + SLOs now stamped $PREV_TAG."
