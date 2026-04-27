#!/usr/bin/env bash
# SCENARIO 1 — Green release.
#
# Opens a feature branch, adds `checkout.cart.size` to the code, the registry,
# and the dashboard. Runs Weaver locally (expects green), opens a PR, waits for
# CI, merges, tags v1.1.0, and lets release.yml run.
#
# Everything is driven by `gh` — make sure you're authenticated.
set -euo pipefail

BR="feat/cart-size-attribute"
TAG="v1.1.0"

log() { printf '\033[1;32m[scenario-1]\033[0m %s\n' "$*"; }

log "creating branch $BR"
git checkout -b "$BR" main

log "patch 1/3 — add span attribute in code"
cat > /tmp/patch1.py <<'PY'
# See demo-app/services/checkout/main.py for the full change.
# Adds: span.set_attribute("checkout.cart.size", len(order.items))
PY
# In the real demo, apply a proper python patch; here we gesture at it:
./demo-app/services/checkout/patches/add-cart-size.sh

log "patch 2/3 — add attribute to weaver/registry/checkout.yaml"
# (Registry already has cart.size defined — if you regenerated registries, skip.)
grep -q 'id: cart.size' weaver/registry/checkout.yaml || cat >> weaver/registry/checkout.yaml <<'YAML'
      - id: cart.size
        type: int
        requirement_level: recommended
        stability: experimental
        brief: "Number of distinct line items in the cart at checkout."
YAML

log "patch 3/3 — add Cart size tile to dashboard"
# The tile is already present in dtctl/dashboards/service-health.yaml — verify:
grep -q 'Cart size distribution' dtctl/dashboards/service-health.yaml || {
  echo "::error::dashboard tile missing — patch manually" && exit 1
}

log "local weaver check + diff"
weaver registry check -r weaver/registry
weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main

log "commit + push"
git add -A
git commit -m "feat(checkout): add cart.size attribute + dashboard tile"
git push -u origin "$BR"

log "opening PR"
PR_URL=$(gh pr create --fill --label "observability")
log "PR: $PR_URL"

log "waiting for CI to pass"
gh pr checks "$PR_URL" --watch

log "merging"
gh pr merge "$PR_URL" --squash --delete-branch

log "tagging $TAG"
git checkout main && git pull
git tag "$TAG"
git push --tags

log "watching release.yml"
RUN_ID=$(gh run list --workflow=release.yml --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID"

log "done. Dashboard should now show app.version=${TAG} with the new tile."
