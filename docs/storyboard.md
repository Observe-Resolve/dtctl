# OBSERVE & RESOLVE — Episode Storyboard
## Dashboards Are Part of Your API

**Channel:** Observe & Resolve · YouTube · Dynatrace
**Host:** Henrik Rexed / Developer Advocate
**Episode:** *TBD — confirm numbering* (working title: Ep. 9 — dtctl + Weaver + SRG)
**Target runtime:** 8:00 (exact, matches channel standard)
**Format:** Voice-over + Screen Demo (brief on-camera segments)
**Stack:** 100% OpenTelemetry (no OneAgent)

---

## The promise to the viewer

> *"In eight minutes, I'm going to show you the workflow senior SREs actually use in 2026 to stop their dashboards from silently lying. Semantic conventions live in OpenTelemetry Weaver and run in CI. Dashboards and SLOs live in `dtctl` manifests, stamped with the release tag. When code drifts from the registry, a Copilot-style watcher files a GitHub ticket; Claude Code resolves it with a deprecation-aware fix. And on release, a Site Reliability Guardian evaluates the new version against SLOs for ten minutes and rolls back if it fails. Everything is text, everything is reviewed, and everything runs in GitHub Actions."*

### What a practitioner walks away knowing how to do

1. **Pin** Dynatrace dashboards and SLOs to a git tag so `v1.1.0` of the app and `v1.1.0` of its observability ship atomically.
2. **Block** a PR in CI when a telemetry attribute is renamed, removed, or type-changed — using `weaver registry diff` against the baseline.
3. **Delegate smartly**: let a Copilot-style watcher *file* drift tickets, let Claude Code *resolve* them using a project-local skill, let humans *review* the resulting PR.
4. **Gate** a release with a Site Reliability Guardian defined in `dtctl/guardians/…yaml`, so a regression auto-rolls-back instead of paging someone at 2 AM.

---

## Section-by-section timing (8:00 total)

| Time | Section | What viewer sees | Teaches |
|---|---|---|---|
| 0:00–0:05 | **Opening / Cold Start** | Title card + Dynatrace logo | Channel identity |
| 0:05–1:20 | **The Pain — silent dashboard drift** | 2 AM pager, dashboard "No data," rename overlay, rotting tiles | Why schema drift silently destroys observability |
| 1:20–2:25 | **The Solution — the five pieces (incl. Argo)** | Numbered tile slide lights up Weaver, dtctl, Copilot watcher, Argo, SRG in turn + skill-stack 2×2 slide | Full stack named; Argo gets first-class airtime |
| 2:25–2:50 | **Demo Setup — cluster + repo** | `kubectl get ns` showing two operators + Argo alongside VS Code tree | Cluster topology + repo layout |
| 2:50–4:15 | **Demo Part 1 — a clean release via GitOps (v1.1.0)** | Tag → CI bumps values file → Argo CD UI reconciles (OutOfSync → Synced) → Argo Rollouts UI walks canary 10/50/100 with green AnalysisRuns → dashboard version badge `v1.1.0` | GitOps rollout with visible Argo CD + Rollouts UIs |
| 4:15–6:00 | **Demo Part 2 — see it break, let Claude fix it (v1.1.1)** | v1.1.1 dashboard visibly failing → watcher files ticket → Claude's produced instrumentation on screen → merge → dashboard recovers | Cost of drift + senior-grade agent repair |
| 6:00–7:30 | **Demo Part 3 — Argo + Guardian stop a bad release (v1.1.2)** | Tag → Argo Rollouts canary at 10% → AnalysisTemplate polls Guardian → fail → Rollout aborts (never cuts over) → dtctl re-stamp + commit comment | Automated release gate with canary abort |
| 7:30–7:40 | **The Bigger Picture** | Daylight talking head | Why this workflow is the 2026 practice |
| 7:40–8:00 | **Wrap-up & CTA** | Repo URL, three `make` targets, subscribe | How to run it yourself |

---

## The six learning outcomes (surfaced across Solution, Bigger Picture, Wrap-up)

1. **Treat telemetry as an API.** Weaver runs in CI. A rename is a breaking change. Block the PR — don't wait for the dashboard to go grey.
2. **Ship Dynatrace config with your git tag.** `dtctl apply -f dtctl/` with `APP_VERSION` stamped into every manifest. Your dashboard's version badge is now ground truth.
3. **Stop running `helm upgrade` from CI.** CI pushes a one-line commit that bumps the image tag in `deploy/helm/values.yaml`. Argo CD reconciles. Your rollouts are observable, reversible, and auditable through Git history.
4. **Your canary should ask the Guardian for permission.** Argo Rollouts `AnalysisTemplate` → `dtctl get guardian-run` → `pass` promotes, `fail` aborts. Bad releases never reach 100%.
5. **Give your agent the right skills and it produces senior-grade instrumentation.** `dtctl`'s own skill teaches Claude to drive the CLI; Dynatrace-for-AI teaches it to read observability data; `observability-agent-skills` teaches it to author OpenTelemetry code with correct semantic conventions, PII protection, and stability flags.
6. **Let Copilot file. Let Claude resolve. Let humans review.** Two agents, two jobs. Pattern recognition → policy application → code review. Never compress that loop.

---

## The three on-camera scenarios (rehearsal cheat sheet)

### Scenario 1 — Clean release (Demo Part 1)

- Branch: `feat/cart-size-attribute`
- Adds `checkout.cart.size` to the span, to `weaver/registry/checkout.yaml`, and a tile in `dtctl/dashboards/service-health.yaml` — all in one PR.
- Merge → `git tag v1.1.0` → `release.yml` stamps the tag and applies.
- Observable result: dashboard shows the new tile, version badge reads `v1.1.0`.

### Scenario 2 — See it break, let Claude fix it (Demo Part 2)

- Branch: `refactor/camelcase-attrs`. Code-only rename of `customer.tier` → `customerTier`. Hotfix pipeline skips Weaver by exception and ships as `v1.1.1` (the pre-staged demo condition).
- **Before the ticket fires**, cut to the live `v1.1.1` dashboard we built in Beat 1 and walk through its failure: the `customer.tier` filter no longer filters anything, the "Checkout errors by customer tier + payment method" table is empty, the `checkout-availability` SLO tile reads `—` instead of a percentage. Make the failure tactile and undeniable.
- Push triggers `.github/workflows/observability-watch.yml` → `scripts/detect-drift.py` → drift issue #42 auto-filed with labels `observability-drift` + `needs-agent`.
- Claude Code loaded with the full skill stack — dtctl, Dynatrace-for-AI, observability-agent-skills, observability-repair — reads the ticket and produces a unified diff across code + registry + dtctl in one commit.
- **On-camera highlight:** hold Claude's produced `checkout/main.py` snippet on screen long enough to read. Call out the hallmarks of the observability-agent-skills pack: both attributes emitted for one release, deprecation comment with removal target, all four required attributes of `checkout.place_order` present per the semantic conventions. That is the "instrumentation produced by the skill."
- After merge, cut back to the dashboard: filter responsive, errors table repopulated, SLO tile flips from `—` back to a live percentage. Recovery is the payoff.
- **Key on-camera framing:** Copilot does pattern recognition; Claude applies policy *with* the skill stack doing the heavy lifting on instrumentation correctness; humans review the PR.

### Scenario 3 — Argo + Guardian stop a bad release (Demo Part 3)

- Pre-staged `v1.1.2` commit carries a deliberate +600ms regression in `payment.charge`.
- `git tag v1.1.2` → `release.yml`:
  1. Builds + pushes the image.
  2. Applies `dtctl/guardians/checkout-release-guardian.yaml` so a Guardian scoped to `app.version="v1.1.2"` starts running.
  3. Rewrites `deploy/helm/values.yaml` (`image.tag: v1.1.2`) and pushes. Argo CD reconciles.
- Argo Rollouts starts the canary: 10% weight, 2-minute soak, then an `AnalysisRun` fires from the `srg-verdict` AnalysisTemplate.
- The AnalysisRun container runs `dtctl get guardian-run --guardian checkout-release-v1.1.2 --latest --output=json | jq -r .verdict` every 30 seconds.
- Guardian's 10-minute evaluation (speed-ramped to ~30s on screen) ends with `fail` — burn-rate + p95 red.
- AnalysisRun returns `fail` → Rollout phase flips to `Degraded` → Rollouts drains traffic away from the canary pods → **stable pods on `v1.1.1` still own 100% of traffic**.
- Nothing was ever "rolled back" in the traditional sense; the bad version never got promoted past 10%.
- `release.yml`'s failure job re-stamps `dtctl/` with `APP_VERSION=v1.1.1` and drops a commit comment on the release commit with the Guardian verdict + a link to the AnalysisRun in Argo.
- Dashboard version badge reverts to `v1.1.1`.

---

## Shot list summary (see Production Notes in `02_teleprompter_script.md` for the full numbered list)

- 2 AM desk + pager overlay
- Empty dashboard ("No data") + rename diff overlay + rotting tiles animation
- Three-box solution explainer + side-by-side dtctl/MCP slide
- VS Code repo tree with four highlighted folders
- PR checks panel all green (Beat 1) and all red for Weaver (Beat 2)
- Terminal tag + Actions `release.yml` runs (Beats 1 and 3)
- Guardian canvas with clock overlay + verdict screen
- Dashboard version badge at `v1.1.0`, `v1.1.2`, flipping back to `v1.1.1`
- End screen with subscribe + next-episode thumbnail

---

## Thumbnail direction

- Left two-thirds: a real-looking Dynatrace dashboard with a big red **"NO DATA"** watermark across it
- Right third: a green GitHub "Merge" button
- Center: tag glyph showing `v1.1.0`
- Bold 3-line text: **"YOUR DASHBOARDS / ARE LYING / TO YOU"**
- Corner badge: "EP · dtctl + Weaver + SRG"

---

## Chapters (for YouTube description)

```
00:00  The 2 AM nightmare — when dashboards lie
01:20  The five pieces: Weaver, dtctl, Copilot, Argo, Guardian
02:25  Cluster + repo tour: two operators, Argo, four folders
02:50  Demo 1 · Clean release via GitOps (v1.1.0)
04:15  Demo 2 · See it break, let Claude fix it (v1.1.1)
06:00  Demo 3 · Argo + Guardian stop a bad release (v1.1.2)
07:30  The bigger picture
07:40  Clone it, try it, tell me
```

---

## Production directives

- **Hard target 8:00.** Channel standard runtime. Do not overshoot — if Beat 2 runs long, trim the Bigger Picture first, not the Guardian.
- **Voice:** direct, second-person, self-deprecating. Match the Smartscape V2 delivery: rhetorical questions, specific numbers read aloud, "hypothetically me," etc.
- **Scenarios must be rehearsed on a real tenant.** The Weaver output and Guardian verdicts are not faked — viewers familiar with the tools will spot staging in one second.
- **Speed-ramp Beat 3's 10-minute Guardian window into ~30 seconds.** Use a visible clock overlay so the compression is honest.
- **Agent appearances cap at ~20 seconds total, all in Beat 2.** This is not an agent episode; it's a workflow episode.
- **Music is less hype than generic YouTube-explainer kicks.** Tech-documentary bed. Drops out for the Recap so the four takeaways land in near-silence.
