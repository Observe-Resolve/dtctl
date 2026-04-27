#!/usr/bin/env bash
# Beat 2 — naïve cleanup PR renames `customer.tier` → `customerTier` in the
# code only. Deliberately does NOT touch:
#   - weaver/registry/checkout.yaml  (the source of truth)
#   - dtctl/dashboards/service-health.yaml  (filters on the old attribute)
#   - dtctl/slos/checkout-availability.yaml  (SLI query filters too)
#
# That's the drift `observability-watch` catches and Claude resolves.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TARGET="$REPO_ROOT/demo-app/services/checkout/main.py"

if grep -q '"customerTier"' "$TARGET"; then
  echo "[rename-customer-tier] already applied — skipping"
  exit 0
fi

# Single-token replace, BSD sed (macOS) compatible.
sed -i '' 's/"customer\.tier"/"customerTier"/g' "$TARGET"

# Sanity check
if grep -q '"customer\.tier"' "$TARGET"; then
  echo "::error::rename incomplete — customer.tier still present in $TARGET" >&2
  exit 1
fi

echo "[rename-customer-tier] customer.tier → customerTier (code only — registry NOT updated)"
