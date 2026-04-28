# Claude Code — project instructions for observe-resolve-ep9-dtctl

You are helping with an **observability-as-code** repo. The hero workflow is a GitHub Actions pipeline that:

1. On PR — runs `weaver registry check` + `weaver registry diff` to block breaking changes to semantic conventions.
2. On `git tag v*` — runs `dtctl apply -f dtctl/` with `APP_VERSION` stamped into every resource.
3. Runs a **Site Reliability Guardian** (`dtctl/guardians/*.yaml`) for 10 minutes post-deploy; auto-rolls-back on failure.

The stack is **100% OpenTelemetry** — no OneAgent. OTel SDKs instrument services; a collector forwards OTLP to Dynatrace.

## Your primary job is REPAIR, not creation

You will most often be invoked when CI fails on a PR, or when the `observability-watch` workflow files a drift ticket. The user wants you to:

1. Read the ticket + the failing CI log.
2. Identify the specific drift or breaking change.
3. Propose the **minimum diff** that follows the rules in `skills/observability-repair/SKILL.md`.
4. Apply the diff after approval.

Do NOT invent new dashboards, SLOs, or metrics unless the user explicitly asks for new ones.

---

## The four skills you run with (install once, use on every task)

This repo is designed to be used by an agent wearing **four skills at once**. Each one covers a different axis.

### 1. dtctl's own agent skill — how to drive the CLI

Source: https://github.com/dynatrace-oss/dtctl/blob/main/skills/dtctl/SKILL.md

Install:
```
dtctl skills install               # auto-detects Claude / Copilot / OpenCode
# or explicitly
dtctl skills install --agent claude
```

Teaches you: every `dtctl` verb, resource types, YAML schemas, `apply`/`get`/`describe`/`diff`/`exec query` patterns. When in doubt about a command shape, defer to this skill.

### 2. Dynatrace-for-AI — the observability *reading* plugin

Source: https://github.com/Dynatrace/dynatrace-for-ai

Install:
```
claude plugin marketplace add dynatrace/dynatrace-for-ai
claude plugin install dynatrace@dynatrace-for-ai
```

Gives you the Dynatrace observability vocabulary: DQL essentials (`dt-dql-essentials`), Smartscape navigation (`dt-migration`), and domain skills — `dt-obs-services`, `dt-obs-tracing`, `dt-obs-kubernetes`, `dt-obs-logs`, `dt-obs-problems`, `dt-app-dashboards`, `dt-app-notebooks`, etc. Use these whenever you're reading live telemetry or reasoning about Dynatrace entities.

### 3. observability-agent-skills — the OTel *writing* pack

Source: https://github.com/henrikrexed/observability-agent-skills

Install:
```
npx skills add henrikrexed/observability-agent-skills
```

Ships five skills that teach you to write correct OpenTelemetry code: `otel-instrumentation` (SDK setup, spans, metrics, logs, PII redaction), `otel-collector` (pipeline config), `otel-ottl` (OTTL reference), `otel-semantic-conventions` (attribute standards + naming), and `otel-dynatrace` (DQL, dashboards, SLOs, dtctl integration). **These are the skills you use whenever you author or repair instrumentation.** When the `observability-repair` workflow says "emit both attributes for one release cycle," these skills give you the right code shape.

### 4. `skills/observability-repair/` — this repo's policy

Source: `./skills/observability-repair/SKILL.md` (project-local)

The rules of *this* repo. Stricter than any upstream skill. When they conflict, follow this one. Teaches the **golden rule**: every migration is a two-release operation.

### Bonus (not loaded by the episode's scenarios)

- `skills/agent-observability/` + `scripts/run-instrumented.sh` + `dtctl/dashboards/agent-activity.yaml` — wrap your own Claude runs in OpenTelemetry spans so the agent's behavior shows up in the same Dynatrace tenant as production. Use if you want to SLO your agent. Optional.

---

## dtctl vs MCP (what to use when)

- **CI/CD and scripts** → `dtctl` via the Bash tool. This is how we ship.
- **Interactive read of live telemetry** → Dynatrace MCP (`mcp__dynatrace__*`) if configured. Treat as optional; prefer `dtctl exec query` when you can.
- **Today's demo runs entirely through dtctl.** Only touch MCP if the user tells you to.

## Hard rules

- Every change to code that emits telemetry MUST land in one PR with: code + registry + dtctl updates. CI will fail otherwise.
- Never rename a stable attribute. Keep the old one deprecated, add the new one, emit both for one release cycle, remove the old one in the next minor.
- SLO targets come from measured data — use `dtctl exec query` against live telemetry to justify any number.
- `dtctl apply -f` is the only write verb. Never `create`, never `patch`.
- Resource files are templated with `${APP_VERSION}`. Do not hardcode versions.
- Before `dtctl apply`, show the rendered diff (`envsubst … | dtctl diff -f -`) and wait for confirmation.

## dtctl cheat sheet

| Action | Command |
|---|---|
| Login | `dtctl auth login` |
| Verify auth | `dtctl auth verify` |
| List dashboards | `dtctl get dashboards` |
| Describe one | `dtctl describe dashboard <name>` |
| Apply YAML (idempotent) | `dtctl apply -f <file\|dir>` |
| Run DQL | `dtctl exec query "<DQL>"` |
| Diff local vs tenant | `dtctl diff -f <file>` |
| Export existing | `dtctl get dashboard <name> -o yaml` |
| Start Guardian | `dtctl apply -f dtctl/guardians/<name>.yaml` |
| Read Guardian verdict | `dtctl get guardian-run --guardian <name> --latest` |

## Weaver cheat sheet

| Action | Command |
|---|---|
| Validate the registry | `weaver registry check -r weaver/registry` |
| Diff against baseline | `weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main` |
| Generate docs | `weaver registry generate markdown -r weaver/registry docs/conventions.md` |
| Freeze a new baseline (after release) | `scripts/freeze-baseline.sh` |

## When Weaver fails on a PR

1. Read the diff output. Classify each change: `added`, `removed`, `renamed`, `type_changed`, `stability_changed`.
2. For `removed` or `renamed` on a *stable* attribute → deprecation overlay: keep old, add new, emit both.
3. For `type_changed` → hard stop. Ask for a new attribute name instead.
4. For `stability_promoted` (experimental → stable): confirm the attribute has been present for ≥ 1 release.
5. Update `weaver/registry/*.yaml` and `dtctl/` in the same diff.
6. Re-run Weaver locally: `make weaver-check` — confirm green before pushing.
