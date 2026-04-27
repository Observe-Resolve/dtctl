#!/usr/bin/env bash
# SCENARIO 3 — Site Reliability Guardian gates a bad release.
#
# Stages a deliberate regression in checkout (added 600ms to payment.charge)
# and tags v1.1.2. release.yml runs, applies the guardian, waits up to 12 min,
# and rolls back automatically when the guardian verdicts `fail`.
set -euo pipefail

TAG="v1.1.2"
log() { printf '\033[1;31m[scenario-3]\033[0m %s\n' "$*"; }

log "applying deliberate regression"
./demo-app/services/checkout/patches/inject-600ms-regression.sh
git checkout -b release/v1.1.2
git add -A
git commit -m "chore(demo): seed v1.1.2 with 600ms regression (for Guardian demo)"
git push -u origin release/v1.1.2

log "opening PR + merging"
PR_URL=$(gh pr create --fill)
gh pr checks "$PR_URL" --watch
gh pr merge "$PR_URL" --squash --delete-branch

log "tagging $TAG"
git checkout main && git pull
git tag "$TAG"
git push --tags

log "watching release.yml"
RUN_ID=$(gh run list --workflow=release.yml --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID"

log "done. Expected outcome: Guardian fails, rollback runs, previous version re-stamped."
