#!/usr/bin/env bash
# Beat 3 — pre-stage a 600ms regression on payment.charge.
#
# This is the deliberately-bad release that:
#   - passes Weaver (no schema change)
#   - passes the unit tests (no functional break)
#   - silently breaks the frontend-p95-latency + error-budget-burn objectives
#   - causes the Site Reliability Guardian's AnalysisRun to verdict `fail`
#   - causes Argo Rollouts to abort the canary at 10% (never reaches 100%)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TARGET="$REPO_ROOT/demo-app/services/checkout/main.py"

if grep -q 'time.sleep(0.6)' "$TARGET"; then
  echo "[inject-600ms-regression] already applied — skipping"
  exit 0
fi

# Insert a sleep right inside the payment.charge span, between provider
# attribute set and outcome.
python3 - <<PY
import pathlib, re
p = pathlib.Path("$TARGET")
s = p.read_text()
new = re.sub(
    r'(span\.set_attribute\("payment\.amount_usd",[^\n]+\n)',
    r'\1\n        time.sleep(0.6)  # DEMO REGRESSION (Beat 3) — Guardian should catch this\n',
    s, count=1
)
assert new != s, "anchor not found — was payment.charge refactored?"
p.write_text(new)
print("[inject-600ms-regression] +600ms latency added to payment.charge")
PY
