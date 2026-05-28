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
git checkout -b "$BR" master

log "patch 1/3 — add span attribute in code"
cat > /tmp/patch1.py <<'PY'
# See demo-app/services/checkout/main.py for the full change.
# Adds: span.set_attribute("checkout.cart.size", len(order.items))
PY
# In the real demo, apply a proper python patch; here we gesture at it:
./demo-app/services/checkout/patches/add-cart-size.sh

log "patch 2/3 — add checkout.cart.size to weaver/registry/checkout.yaml"
if ! grep -q 'id: checkout.cart.size' weaver/registry/checkout.yaml; then
  # Insert the attribute definition before checkout.order.total_usd
  python3 - <<'PY'
import pathlib, re
p = pathlib.Path("weaver/registry/checkout.yaml")
s = p.read_text()

# Add attribute definition before checkout.order.total_usd
attr_block = """      - id: checkout.cart.size
        type: int
        requirement_level: recommended
        stability: experimental
        brief: "Number of distinct line items in the cart at checkout."
        examples: [1, 5]

      - id: checkout.order.total_usd"""
s = s.replace("      - id: checkout.order.total_usd", attr_block, 1)

# Add span ref before checkout.order.total_usd ref
ref_block = """      - ref: checkout.cart.size
      - ref: checkout.order.total_usd"""
s = s.replace("      - ref: checkout.order.total_usd", ref_block, 1)

p.write_text(s)
print("[scenario-1] added checkout.cart.size to registry")
PY
else
  echo "[scenario-1] checkout.cart.size already in registry — skipping"
fi

log "patch 3/3 — add Cart size distribution tile to dashboard"
if ! grep -q 'Cart size distribution' dtctl/dashboards/service-health.yaml; then
  python3 - <<'PY'
import pathlib, yaml

p = pathlib.Path("dtctl/dashboards/service-health.yaml")
s = p.read_text()

# Insert new layout "10" (beside tile 7 — Checkout error rate, same row, half-width)
# and new tile "10" with the histogram query.
# We add layout entry and tile entry by appending before the closing sections.

# Add layout for tile 10: same row as tile 7 (y:13), right half
layout_entry = '''    "10":
      h: 5
      w: 12
      x: 12
      "y": 13'''

tile_entry = '''    "10":
      davis:
        davisVisualization:
          isAvailable: true
        enabled: false
      query: |
        fetch spans, from:now()-1h
        | filter service.name == "checkout"
        | filter span.name == "oteldemo.CheckoutService/PlaceOrder"
        | filter app.version == "${APP_VERSION}"
        | filter isNotNull(checkout.cart.size)
        | summarize count(), by: bins(checkout.cart.size, 10)
      querySettings:
        defaultSamplingRatio: 10
        defaultScanLimitGbytes: 500
        enableSampling: false
        maxResultMegaBytes: 1
        maxResultRecords: 1000
      title: Cart size distribution
      type: data
      visualization: histogram
      visualizationSettings:
        autoSelectVisualization: false'''

# Shrink tile 7 to left half (w:12 x:0) so tile 10 sits beside it.
# Tile 7 is already at x:12 y:13 w:12 — move it to x:0 to make room,
# or keep tile 7 where it is and put 10 at x:0. Actually tile 7 is already
# at x:12, so tile 10 goes at x:0.

# Insert layout "10" after layout "9"
s = s.replace(
    '''    "9":
      h: 6
      w: 12
      x: 12
      "y": 18''',
    '''    "9":
      h: 6
      w: 12
      x: 12
      "y": 18
''' + layout_entry,
)

# Insert tile "10" after tile "9" block (before variables)
s = s.replace(
    "  variables: []",
    tile_entry + "\n  variables: []",
)

p.write_text(s)
print("[scenario-1] added Cart size distribution tile to dashboard")
PY
else
  echo "[scenario-1] Cart size distribution tile already in dashboard — skipping"
fi

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
git checkout master && git pull
git tag "$TAG"
git push --tags

log "watching release.yml"
RUN_ID=$(gh run list --workflow=release.yml --limit=1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID"

log "done. Dashboard should now show app.version=${TAG} with the new tile."
