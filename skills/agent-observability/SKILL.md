---
name: agent-observability
description: >
  (Deprecated / optional bonus.) Early draft that framed this repo around
  "agents observing themselves." The episode scope moved to agents PRODUCING
  correct instrumentation via the upstream observability-agent-skills pack.
  See skills/README.md and CLAUDE.md for the live skill stack.
---

# agent-observability — optional bonus only

> **This skill is NOT loaded by the scenarios on camera.** It was part of an earlier draft and is kept as an optional bonus for practitioners who want to instrument their own Claude Code runs. It is not required to reproduce the episode.

The main skill stack for this repo is:

1. **dtctl's own agent skill** — https://github.com/dynatrace-oss/dtctl/blob/main/skills/dtctl/SKILL.md
2. **Dynatrace-for-AI** (Claude plugin marketplace) — https://github.com/Dynatrace/dynatrace-for-ai
3. **henrikrexed/observability-agent-skills** (OTel authoring skills) — https://github.com/henrikrexed/observability-agent-skills
4. **`skills/observability-repair/`** (project-local policy)

If you nevertheless want to wrap your own Claude Code invocations in an OpenTelemetry span so agent activity lands in your Dynatrace tenant next to production telemetry:

- `scripts/run-instrumented.sh` emits a span + start/finish logs via `otel-cli`.
- `dtctl/dashboards/agent-activity.yaml` queries those spans.
- `weaver/registry/_agent.yaml` defines the semantic conventions for those spans, so they flow through the same Weaver CI gate as production telemetry.

These three files are intentionally decoupled from the hot path. Use them, don't use them — the episode doesn't require them.
