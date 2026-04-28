#!/usr/bin/env bash
# Roll back to the previous semver tag on main.
# Called by release.yml when the Guardian returns `fail`.
#
# Dashboards and SLOs are version-agnostic (long-lived) — no re-stamping needed.
# Only the Guardian carries a version suffix (it's a per-release gate by design).
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

# 1. Argo Rollouts undo to the previous revision
kubectl-argo-rollouts undo rollout checkout -n otel-demo --timeout 5m

# 2. Re-stamp and apply only the guardian at the previous version
APP_VERSION="$PREV_TAG" envsubst '${APP_VERSION}' < dtctl/guardians/checkout-release-guardian.yaml \
  | dtctl apply -f -

# 3. Log the rollback event
log "Guardian checkout-release-${APP_VERSION} validation failed — rolled back to ${PREV_TAG} at $(date -u +%FT%TZ)"

log "rollback complete. Guardian re-stamped to $PREV_TAG. Dashboards and SLOs are version-agnostic — no changes needed."
