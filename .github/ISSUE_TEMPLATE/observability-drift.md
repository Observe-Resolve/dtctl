---
name: Observability drift
about: Auto-filed by the observability-watch workflow when telemetry code changes aren't matched by registry/dashboard updates.
labels: ["observability-drift", "needs-agent"]
---

> **Auto-filed by the observability-watch workflow.** A human — or an agent — needs to keep the code, the Weaver registry, and the dtctl manifests in sync before this branch merges.

## Where the drift was detected

- **Branch:** `{{BRANCH}}`
- **Commit:** `{{COMMIT}}`

## What drifted

| Kind | Attribute | Location | Suggested fix |
|---|---|---|---|
{{DRIFTS}}

<details>
<summary>Raw drift report (JSON)</summary>

```json
{{JSON}}
```
</details>

---

## Claude Code — one-click resolver

Run this from the repo root:

```bash
gh issue view <this-issue-number> > /tmp/ticket.md
claude code \
  --skill skills/observability-repair \
  --prompt "$(cat prompts/scenario-2-resolve-drift.md | sed -n '/^---PROMPT BELOW---$/,$ p' | tail -n +2)
TICKET:
$(cat /tmp/ticket.md)"
```

Claude will:

1. Read this ticket and the drift JSON.
2. Read the current code, registry, and dtctl manifests.
3. Apply the **observability-repair** skill's rules:
   - Deprecate renamed attributes with a one-release overlap.
   - Never drop a stable attribute in the same PR that introduces the replacement.
   - Keep dashboard + SLO filters compatible with both old and new attributes during the overlap window.
4. Open a PR that closes this issue.

## GitHub Copilot handoff (alternative)

If your org has GitHub Copilot Workspace / Agents enabled, the `needs-agent` label on this issue is sufficient — Copilot will auto-propose a PR. The Claude Code path above is the fallback and the one demonstrated in the Observe & Resolve episode.

## Human review checklist (before merging the resolver PR)

- [ ] Old attribute kept with `deprecated: true` in the registry.
- [ ] New attribute added with `stability: experimental` (promote to stable next minor).
- [ ] Code emits both old and new attributes for one release.
- [ ] Dashboard `fieldsAdd` uses `coalesce(old, new)` so existing panels keep working.
- [ ] SLO SLI queries use `coalesce(old, new)` similarly.
- [ ] `weaver registry diff` passes against `weaver/baselines/main`.
