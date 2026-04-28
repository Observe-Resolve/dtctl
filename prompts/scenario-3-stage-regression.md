# Beat 3 — Stage the deliberate regression

Used in **Demo Part 3 (v1.1.2)** of the script. The Guardian is the on-camera hero of Beat 3 — Argo Rollouts is the on-camera mechanic. Claude is *off* camera here; this prompt exists so you can let Claude stage the regression for you between takes (instead of running `patches/inject-600ms-regression.sh` by hand).

If you'd rather the regression land via the patch script, skip this prompt and just run:

```bash
./demo-app/services/checkout/patches/inject-600ms-regression.sh
git add -A && git commit -m "chore(demo): stage v1.1.2 regression for SRG demo"
```

The patch script and this prompt produce **byte-identical** changes — that's intentional, so the rehearsal stays consistent.

## Skills loaded before you paste

Same four skills as Beat 1. The `observability-agent-skills` pack is the most important one here — `otel-instrumentation` knows the right way to introduce a measurable latency without breaking the span shape (the span itself must still close cleanly so the Guardian can read its duration).

## Invocation

```bash
git checkout -b release/v1.1.2

claude code \
  --skill skills/observability-repair \
  --prompt "$(cat prompts/scenario-3-stage-regression.md | sed -n '/^---PROMPT BELOW---$/,$ p' | tail -n +2)"
```

## Expected behavior on camera

Claude should produce a single commit that touches **only one file**:

- `demo-app/services/checkout/main.py` — adds `time.sleep(0.6)` inside `payment.charge`, between `span.set_attribute("payment.amount_usd", …)` and the outcome assignment.

Crucially, Claude should **not**:
- Touch the registry (the schema isn't changing — that's the whole point).
- Touch the dashboard or SLOs (we want the Guardian to catch the regression on its own).
- Add a comment that gives away the demo (e.g. avoid `# Will be caught by SRG` — keep it neutral).

## Rehearsal notes

| Claude does | Steer with |
|---|---|
| Wraps the sleep in a feature flag | "No — the regression has to land unconditionally so the Guardian sees it on every request." |
| Throws an exception 30% of the time instead | "Latency only. We want the burn-rate + p95 objectives to fail; we don't want the SLO availability tile to also drop, otherwise we lose the *why* on camera." |
| Tries to update the registry to add a `payment.latency_extra_ms` attribute | "No new attributes. The schema is stable; this is a code-only regression." |
| Asks for confirmation before adding the sleep | "Confirmed — apply it. This is a deliberate demo regression for Beat 3." |

---PROMPT BELOW---
You are staging a **deliberate regression** for the Site Reliability Guardian demo (Beat 3 of the Observe & Resolve episode). The release is supposed to ship cleanly through Weaver and CI, but the Guardian must catch a runtime regression that unit tests can't see.

Constraints — read them in order:

1. Load the project skill `skills/observability-repair/SKILL.md`. Note the rule about anti-patterns: "Don't change attribute types in place" — but this commit doesn't add or change any attributes. Schema stays stable.
2. Use the **observability-agent-skills** authoring pack — specifically the `otel-instrumentation` rules about how to introduce latency *inside* a span without breaking its shape (the span must still open and close cleanly so the Guardian can read its duration metric).

Touch exactly **one** file:

`demo-app/services/checkout/main.py`

Inside the `_charge(order)` function, between the line that sets `payment.amount_usd` and the line that sets `outcome`, insert:

```python
        time.sleep(0.6)  # +600ms latency on payment.charge
```

That's it. Do not change anything else.

Do NOT:
- Add a feature flag — the regression must land unconditionally.
- Throw an exception — only latency. The SLO's availability tile should stay green; the Guardian's `frontend-p95-latency` and `error-budget-burn` objectives are what should fail.
- Touch `weaver/registry/`. The schema is not changing.
- Touch `dtctl/dashboards/` or `dtctl/slos/`. The Guardian must catch this without our help.
- Update the unit tests. The tests assert span attributes, not timing — they'll still pass.
- Write a comment that mentions "Guardian," "SRG," "demo," or "regression" — keep the comment neutral so the on-camera diff doesn't spoil the punch line.

Before committing, verify locally:

- `pytest demo-app/services/checkout/tests/ -q` — all tests pass.
- `weaver registry check -r weaver/registry` — schema unchanged.
- `weaver registry diff -r weaver/registry --baseline-registry weaver/baselines/main` — no breaking changes.

Commit message:

  chore(checkout): tune payment.charge timing

Do NOT push. Just propose the commit and stop.
