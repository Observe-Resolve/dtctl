---
name: observability-repair
description: >
  Resolve observability-drift tickets filed by the observability-watch workflow
  (or GitHub Copilot Workspace). Apply deprecation-aware fixes that keep the code,
  the Weaver registry, and the dtctl manifests in sync. Never introduce breaking
  changes in a single PR. Use when a ticket is labeled `observability-drift`,
  when CI's weaver-diff step fails, or when the user asks you to "resolve drift",
  "fix observability ticket", or "repair registry".
---

# observability-repair

## Purpose

Observability in this repo is a contract with three consumers:

1. **The code** — what the service actually emits.
2. **The registry** — what we promise to emit (`weaver/registry/`).
3. **The dashboards and SLOs** — what we measure (`dtctl/`).

These three must never drift. When they do, a ticket is filed. This skill is
the playbook you follow to close that ticket without breaking the contract.

## The golden rule

**Every migration is a two-release operation.**

- Release N: keep the old, add the new, emit both.
- Release N+1: remove the old.

One PR never both removes a stable attribute AND adds its replacement in a
breaking way.

## The five drift kinds and their fixes

### 1. `renamed` — e.g. `customer.tier` → `customerTier`

**Fix:**
- In `weaver/registry/`: keep `customer.tier`, mark `deprecated: true` with a
  `deprecated_reason: "renamed to customerTier"`. Add `customerTier` with
  `stability: experimental`.
- In code: emit **both** attributes for one release. `span.set_attribute("customer.tier", …)` AND `span.set_attribute("customerTier", …)`.
- In `dtctl/` queries, use `coalesce(customerTier, customer.tier)` so the dashboard works for both versions.

### 2. `added_to_code` — new attribute not in registry

**Fix:**
- Add an entry to `weaver/registry/`, matching the domain.
- Pick `stability: experimental` unless the attribute is a direct adoption of a stable upstream OpenTelemetry semantic convention.
- Write a non-trivial `brief` — treat it like public API documentation.
- If it's worth showing on the dashboard, add a tile in the same PR; otherwise note it for the next sprint.

### 3. `removed_from_code` — attribute still in registry but code no longer emits

**Fix:**
- Do **not** remove it from the registry in this PR. Mark `deprecated: true` instead.
- Scan `dtctl/` for queries that filter on it. Update them to use `coalesce(...)` with the replacement if one exists, or delete the tile with a clear commit message.
- Open a follow-up issue "Remove deprecated `<attr>` in next minor release."

### 4. `type_changed` — e.g. `order.total_usd` was string, now double

**Fix:** Hard stop. Type changes are not migratable. Propose a new attribute name (e.g. `order.total_usd_v2`) with the correct type, deprecate the old one, and leave the ticket open for the tech-lead to approve.

### 5. `stability_promoted` — experimental → stable

**Fix:**
- Verify the attribute has been present for ≥ 1 tagged release (`git log` on the registry file).
- Ensure it's emitted by *all* relevant services, not just one.
- Flip `stability: experimental` → `stable`. Update the `brief` to remove any "experimental" language.

## Workflow when resolving a ticket

1. **Read the ticket.** The drift JSON tells you exactly what changed and where.
2. **Classify each drift** using the five kinds above. A single ticket often has two or three kinds.
3. **Propose the minimum diff.** Show the user the diff before applying.
4. **Apply in one commit** with a message that matches this template:
   ```
   fix(observability): resolve drift #<issue-number> — <one-line summary>

   - code: <what changed>
   - registry: <what changed>
   - dtctl: <what changed>

   Closes #<issue-number>.
   ```
5. **Validate locally before pushing.** Run:
   ```
   weaver registry check -r weaver/registry
   weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main
   ./scripts/stamp-version.sh > /tmp/rendered.yaml
   dtctl validate -f /tmp/rendered.yaml
   ```
6. **Open a PR that references the issue.** Do not close the issue manually — let the squash-merge close it.

## Anti-patterns (never do these)

- ❌ Removing a stable attribute in the same PR that adds its replacement.
- ❌ Changing an attribute's type in place.
- ❌ Adding an attribute to code without a registry entry.
- ❌ Renaming an attribute without a `coalesce(...)` in the dashboard.
- ❌ Skipping `weaver registry diff` locally "because CI will catch it".

## When to ask the human

- Any `type_changed` drift.
- Any change that promotes experimental → stable.
- Any drift that touches more than 5 attributes at once (that's a refactor, not a drift).
- Any case where the heuristic rename detection looks wrong (e.g. `cart.size` and `cart.total` are *not* a rename pair).

## Related skills

- Upstream **`dynatrace-for-ai`** skills (`github.com/Dynatrace/dynatrace-for-ai`) for DQL + Dynatrace object model.
- This skill is stricter; when they conflict, follow this one.
