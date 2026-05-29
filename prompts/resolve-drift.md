# Generic observability-drift resolver prompt

Use this prompt to resolve **any** observability-drift ticket, not just the `customer.tier` demo scenario. For the demo-specific version, see `prompts/scenario-2-resolve-drift.md`.

## How to invoke

```bash
gh issue view <ISSUE_NUMBER> --comments > /tmp/ticket.md
claude -p "$(cat prompts/resolve-drift.md)
TICKET:
$(cat /tmp/ticket.md)"
```

---PROMPT BELOW---
You are resolving an observability-drift ticket filed by the observability-watch workflow. The ticket body — including any comments from GitHub Copilot or other reviewers — is appended below after the TICKET: marker.

Before you change anything:

1. Load and follow the project skill at `skills/observability-repair/SKILL.md`. Its rules override generic advice. The golden rule is "every migration is a two-release operation."
2. Use the **observability-agent-skills** authoring pack (`otel-instrumentation` + `otel-semantic-conventions`) to make sure the code change is shaped correctly — proper deprecation comments, both attributes emitted during the overlap, no PII leaks.
3. Read the drift JSON inside the ticket. For each drift, classify it using the five kinds below.
4. Read the **Impacted files** section in the ticket. It tells you exactly which files in code, registry, and dtctl reference the drifted attributes.
5. Read the **comments** on the ticket. The issue may contain a Copilot analysis with per-file fix recommendations. Use these as guidance but **validate every recommendation against the SKILL.md policy** — Copilot may suggest removing an attribute outright instead of deprecating it.

## Per-drift-kind fix instructions

### `renamed` — e.g. `old.name` -> `newName`

1. **Registry** (`weaver/registry/*.yaml`): Keep the old attribute entry. Add `deprecated: true` and `deprecated_reason: "renamed to newName"`. Add a new entry for the new name with `stability: experimental`, same type, `requirement_level: recommended`.
2. **Code** (source files): Keep the old `set_attribute("old.name", ...)` line with a deprecation comment. Add a new line directly below: `set_attribute("newName", ...)`. Both must emit the same value.
3. **dtctl** (dashboards, SLOs, queries): Replace every bare reference to `old.name` with `coalesce(newName, old.name)` so panels and SLOs work during the one-release overlap.

### `added_to_code` — new attribute not in registry

1. **Registry**: Add the attribute to the appropriate `weaver/registry/*.yaml` file. Use `stability: experimental`. Write a non-trivial `brief`.
2. **Code**: No code change needed (it's already emitting).
3. **dtctl**: If the attribute is dashboard-worthy, add a tile in the same PR. Otherwise note it for the next sprint.

### `removed_from_code` — attribute still in registry, code no longer emits

1. **Registry**: Do NOT remove. Mark `deprecated: true` with a `deprecated_reason`.
2. **Code**: No code change (it's already gone).
3. **dtctl**: Scan for queries that filter on it. Use `coalesce(replacement, old)` if a replacement exists, or add a comment noting the tile will go blank after the next release.
4. Open a follow-up issue: "Remove deprecated `<attr>` in next minor release."

### `type_changed` — e.g. string -> double

Hard stop. Type changes are not migratable in place. Propose a new attribute name (e.g. `attr_v2`) with the correct type, deprecate the old one, and ask the user to approve before proceeding.

### `stability_promoted` — experimental -> stable

1. Verify the attribute has been present for >= 1 tagged release (`git log` on the registry file).
2. Flip `stability: experimental` -> `stable`. Update the `brief` to remove "experimental" language.
3. Ask the user to confirm before applying — promotions are one-way.

## Commit format

All changes go in one commit:

```
fix(observability): resolve drift #<issue-number> — <one-line summary>

- code: <what changed>
- registry: <what changed>
- dtctl: <what changed>

Closes #<issue-number>.
```

## Before committing, validate locally

- `weaver registry check -r weaver/registry`
- `weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main`

Both must pass. If the diff flags a breaking change, you missed a deprecation overlay.

Do NOT push. Propose the commit and stop.
