#!/usr/bin/env bash
# Beat 1 — feature PR adds the `checkout.cart.size` span attribute.
#
# Adds one line to checkout/main.py just inside the place_order span,
# matching the experimental attribute declared in weaver/registry/checkout.yaml.
# The dashboard tile "Cart size distribution" reads from this attribute.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TARGET="$REPO_ROOT/demo-app/services/checkout/main.py"

if grep -q 'checkout.cart.size' "$TARGET"; then
  echo "[add-cart-size] already applied — skipping"
  exit 0
fi

# Insert the attribute right after the order.total_usd line.
# The exact comment markers in main.py make this anchor stable across edits.
python3 - <<PY
import pathlib, re
p = pathlib.Path("$TARGET")
s = p.read_text()
new = re.sub(
    r'(span\.set_attribute\("order\.total_usd",[^\n]+\n)',
    r'\1        span.set_attribute("checkout.cart.size", len(order.items))\n',
    s, count=1
)
assert new != s, "anchor not found in main.py — was the file refactored?"
p.write_text(new)
print("[add-cart-size] inserted span.set_attribute(\"checkout.cart.size\", ...)")
PY
