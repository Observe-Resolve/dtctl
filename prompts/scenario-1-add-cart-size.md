# Beat 1 — Add the `checkout.cart.size` attribute

Used in **Demo Part 1 (v1.1.0)** of the script. This is the "feature PR done right" — code, semantic conventions, and dashboard updated in a single commit. Demonstrates the disciplined-engineer baseline before Beats 2 and 3 break it.

## Skills loaded before you paste

```bash
# All four installed once, on your machine
dtctl skills install --agent claude
# dynatrace-for-ai skills are loaded via MCP server config in .claude/settings.json
# (see https://github.com/Dynatrace/dynatrace-for-ai for setup)
npx skills add henrikrexed/observability-agent-skills
# (project-local skills/observability-repair/ is referenced in the prompt text below)
```

## Invocation (paste into a fresh shell at the repo root, on a feature branch)

```bash
git checkout -b feat/cart-size-attribute

claude -p "$(cat prompts/scenario-1-add-cart-size.md | sed -n '/^---PROMPT BELOW---$/,$ p' | tail -n +2)" \
  --allowedTools Edit Write Bash
```

## Expected behavior on camera

Claude should produce a single commit that touches **three files**, in this order:

1. `weaver/registry/checkout.yaml` — adds `checkout.cart.size` as `experimental` / `recommended`
2. `demo-app/services/checkout/main.py` — adds `span.set_attribute("checkout.cart.size", ...)` inside `PlaceOrder` (stub count — `PlaceOrderRequest` doesn't carry items directly)
3. `dtctl/dashboards/service-health.yaml` — adds a "Cart size distribution" tile filtered on `app.version` + `checkout.cart.size`

Then `weaver registry check` + `weaver registry diff` + `dtctl validate` locally — all green.

## Rehearsal notes — what to do if Claude wanders

| Claude does | Steer with |
|---|---|
| Tries to update only the code | "Stop. Read `skills/observability-repair/SKILL.md` again. The golden rule is code + registry + dashboard in the same diff." |
| Picks `stability: stable` for the new attribute | "We're following the rules in the project skill. New attributes go in as `experimental`. We promote in the next release." |
| Adds the attribute to `checkout.place_order` AND `payment.charge` | "Only `checkout.place_order` for now. `payment.charge` is owned by a different team." |
| Wants to rebuild the image | "No build. Just propose the diff. CI will build on the tag push." |

---PROMPT BELOW---
You are adding a **feature** to the checkout service: a new `checkout.cart.size` span attribute that the dashboard will visualize as a distribution histogram.

Constraints — read them in order:

1. Load the project skill `skills/observability-repair/SKILL.md` first. Its rules override generic advice.
2. Use the **observability-agent-skills** OTel authoring skills (`otel-instrumentation`, `otel-semantic-conventions`) to make sure the code, the registry entry, and the dashboard query all line up.

Touch exactly three files in one commit:

1. `weaver/registry/checkout.yaml`
   - Add `checkout.cart.size` as a new attribute under the `checkout` group.
   - `type: int`, `requirement_level: recommended`, `stability: experimental`.
   - Add a one-line `brief:` and `examples:`.
   - Reference it from the `oteldemo.CheckoutService.PlaceOrder` span definition.

2. `demo-app/services/checkout/main.py`
   - Inside `PlaceOrder`, after the `span.set_attribute("order.total_usd", …)` line, add:
     `span.set_attribute("checkout.cart.size", ...)` with the item count (note: the demo's `PlaceOrderRequest` proto has no `items` field — use a stub count for demo purposes).
   - Keep the comment block above the existing attributes — that block documents what's required and what's recommended.

3. `dtctl/dashboards/service-health.yaml`
   - Add a tile of `type: histogram` titled "Cart size distribution" that runs:
     ```dql
     fetch spans, from:now()-1h
     | filter service.name == "checkout"
     | filter span.name == "oteldemo.CheckoutService/PlaceOrder"
     | filter app.version == "${APP_VERSION}"
     | filter isNotNull(checkout.cart.size)
     | summarize count(), by: bins(checkout.cart.size, 10)
     ```
   - Insert the tile beside the existing "Checkout error rate (5m)" tile, same row, half-width each.

Before committing, run locally:

- `weaver registry check -r weaver/registry`
- `weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main`
- `dtctl validate -f <(./scripts/stamp-version.sh)`

All three must pass. If any of them fail, fix and re-run before you propose the commit.

Commit message:

  feat(checkout): add cart.size attribute + dashboard tile

  - code: span.set_attribute("checkout.cart.size", ...) in PlaceOrder
  - registry: new experimental attribute referenced from oteldemo.CheckoutService.PlaceOrder
  - dashboard: histogram tile filtered on app.version

Do NOT push. Do NOT build the image. Just propose the commit and stop.
