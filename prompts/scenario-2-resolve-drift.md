# Beat 2 — Resolve a drift ticket Copilot just filed

Used in **Demo Part 2 (v1.1.1)** of the script. Pre-condition: a teammate has pushed a code-only rename of `customer.tier` → `customerTier`, the `observability-watch` workflow has filed GitHub Issue **#42** with label `observability-drift`. We're handing the ticket to Claude.

## Skills loaded before you paste

Same four skills as Beat 1 (see `prompts/scenario-1-add-cart-size.md`).

## Invocation (paste at the repo root, on the offending branch)

```bash
# Pull the ticket body into a file Claude can see
gh issue view 42 > /tmp/ticket.md

claude code \
  --skill skills/observability-repair \
  --prompt "$(cat prompts/scenario-2-resolve-drift.md | sed -n '/^---PROMPT BELOW---$/,$ p' | tail -n +2)
TICKET:
$(cat /tmp/ticket.md)"
```

## Expected behavior on camera

Claude should produce a single commit that:

1. **Keeps `customer.tier`** in `weaver/registry/checkout.yaml` but marks it `deprecated: true` with a `deprecated_reason: "renamed to customerTier"`.
2. **Adds `customerTier`** in the same registry file as `experimental`.
3. **In `demo-app/services/checkout/main.py`** — emits **both** attributes (the old one for the overlap release, the new one going forward).
4. **In `dtctl/dashboards/service-health.yaml` and `dtctl/slos/checkout-by-tier.yaml`** — wraps every reference to `customer.tier` in `coalesce(customerTier, customer.tier)` so the dashboard tile and the SLO continue to measure during the overlap.

Then `weaver registry diff` against `main` baseline locally — green.

## Rehearsal notes — what to do if Claude wanders

| Claude does | Steer with |
|---|---|
| Removes `customer.tier` from the registry | "Stop. The golden rule is two-release migration. Keep the old, mark it deprecated, add the new. Re-read the skill." |
| Updates the code only | "Three files: code, registry, dtctl. Same commit. Read the ticket again — the watcher detected drift across all three." |
| Picks `stability: stable` for `customerTier` | "New attributes always start `experimental`. Promote in the next minor." |
| Forgets the `coalesce()` in dashboard/SLO queries | "The overlap window means the dashboard tile and checkout-by-tier SLO need to see both names. Use coalesce." |
| Tries to also fix the unit tests | "Tests should still pass — they assert the four required attributes are present, and `customer.tier` still IS present (deprecated, but emitted). Don't touch the tests." |

---PROMPT BELOW---
You are resolving an observability-drift ticket filed by GitHub Copilot / the observability-watch workflow. The ticket body is appended below after the TICKET: marker.

Before you change anything:

1. Load and follow the project skill at `skills/observability-repair/SKILL.md`. Its rules override generic advice. The golden rule is "every migration is a two-release operation."
2. Use the **observability-agent-skills** authoring pack (`otel-instrumentation` + `otel-semantic-conventions`) to make sure the code change is shaped correctly — proper deprecation comments, both attributes emitted during the overlap, no PII leaks.
3. Read the drift JSON inside the ticket. For each drift, classify it (`renamed`, `added_to_code`, `removed_from_code`, `type_changed`, `stability_changed`). The ticket from the watcher is for a `renamed` drift on `customer.tier` → `customerTier`.

Touch exactly three files in one commit:

1. `weaver/registry/checkout.yaml`
   - Keep the existing `customer.tier` entry. Add `deprecated: true` and `deprecated_reason: "renamed to customerTier"` to it. Update the `brief:` to mention the deprecation.
   - Add a new attribute entry for `customerTier`. Same `type` as the original. `stability: experimental`. `requirement_level: recommended`.
   - The `checkout.place_order` span definition must reference both attributes.

2. `demo-app/services/checkout/main.py`
   - Keep the line that sets `customer.tier`. Add a comment above it: `# DEPRECATED — keep for one release so v1.1.0 dashboards still resolve. Remove in v1.2.0.`
   - Add a new line directly below: `span.set_attribute("customerTier", order.customer_tier)` with a comment `# NEW — target name going forward. Mirrors the registry entry.`

3. `dtctl/dashboards/service-health.yaml` AND `dtctl/slos/checkout-by-tier.yaml`
   - Find every reference to `customer.tier`. Replace with `coalesce(customerTier, customer.tier)`.
   - The dashboard tile "Orders by customer tier" and the `checkout-by-tier` SLO both filter on `isNotNull(customer.tier)` — without coalesce they go blank the moment the rename lands.
   - This keeps the tile and the SLO measuring during the one-release overlap window.

Before committing, run locally:

- `weaver registry check -r weaver/registry`
- `weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main`
- `pytest demo-app/services/checkout/tests/ -q`

All three must pass. If pytest fails because the test asserts `customer.tier` is present, that's correct — it should still be present, you're keeping it. If the diff still flags a breaking change, you missed adding `deprecated: true` somewhere.

Commit message:

  fix(observability): resolve drift #<issue-number> — deprecate customer.tier, add customerTier

  - code: emit both customer.tier (deprecated) + customerTier (new)
  - registry: deprecation overlay; new attribute as experimental
  - dtctl: dashboard tile + checkout-by-tier SLO use coalesce(customerTier, customer.tier)

  Closes #<issue-number>.

Do NOT remove `customer.tier` from anywhere in this PR. That removal happens in the next minor release.

Do NOT push. Just propose the commit and stop.
