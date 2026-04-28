# OBSERVE & RESOLVE
## YouTube Playlist | Dynatrace

# Dashboards Are Part of Your API

### Shipping Observability with Your App Using dtctl, Weaver, Copilot & Claude

**Duration:** 8 minutes
**Episode:** *TBD — confirm numbering* (working title: Ep. 9 — dtctl + Weaver + SRG)
**Format:** Host on sofa, sustained voiceover. Screen alternates between **diagrams/schemas** (explaining concepts) and **screen recordings** (showing things happen). Brief on-camera cutaways at the Opening and Wrap-up only.
**Author:** Henrik Rexed / Developer Advocate

> **SCREEN CUE conventions** used below:
>
> - **DIAGRAM:** an animated or static schema that illustrates a concept (built in post, no footage capture needed)
> - **SCREEN:** a screen recording of a real tool (Dynatrace UI, GitHub UI, VS Code, Argo UIs, terminal)
> - **ON-CAMERA:** Henrik visible on the sofa (use sparingly — opener + bigger picture + wrap-up)
> - **TITLE CARD:** a static text slide

---

## Timing Overview

| Section | Duration |
|---|---|
| Opening / Cold Start | 0:05 |
| The Pain Point | 1:25 |
| The Solution — The Five Pieces (with primers) | 1:00 |
| Demo Setup — Cluster + Repo | 0:20 |
| Demo Part 1 — A Clean Release via GitOps (v1.1.0) | 1:25 |
| Demo Part 2 — See It Break, Let Claude Fix It (v1.1.1) | 1:40 |
| Demo Part 3 — Argo + Guardian Stop a Bad Release (v1.1.2) | 1:25 |
| The Bigger Picture | 0:10 |
| Wrap-up & CTA | 0:20 |
| **TOTAL** | **8:00** |

---

## 00:00–00:05 · OPENING / COLD START

**TITLE CARD:** Animated title card with upbeat music. *"Dashboards Are Part of Your API"* slides in. Dynatrace logo. Episode badge: "Observe & Resolve."

**ON-CAMERA:** Henrik on the sofa, casual framing, ~10 seconds.

**VOICEOVER:** Hey everyone, welcome back to "Observe & Resolve," your go-to series for troubleshooting and analyzing cloud-native technologies. I'm Henrik Rexed, and today we're going to talk about the quiet, expensive way your observability lies to you — and how to stop it.

---

## 00:05–1:30 · THE PAIN POINT

**VOICEOVER:** Think about this. How many of you have opened a Dynatrace dashboard that *should* have data — and you get nothing but "No data" tiles? The app is fine. The dashboard is broken. Raise your hand. I see you. I've been there too.

**VOICEOVER:** Context: every signal on this dashboard comes from OpenTelemetry SDKs my team wrote into our own code. No OneAgent auto-pickup. Our code owns the attribute names.

**SCREEN:** Dynatrace dashboard recording — every tile shows "No data." Hold on this shot.

**VOICEOVER:** Here's the ugly truth. Your observability is drifting. Somebody on your team renamed a span attribute — `customer.tier` became `customerTier`. Seemed cosmetic. Tests passed. Release went out.

**DIAGRAM:** Highlight one of the empty tiles. A small code-diff panel animates in on top showing `customer.tier` → `customerTier`.

**VOICEOVER:** And that one rename silently disconnected four dashboard tiles, two SLOs, and an alert. The tiles kept rendering — against zero events. The SLO kept evaluating — against zero events. And the first thing that told you something was wrong? Was a user.

**DIAGRAM:** Animated schema — a week-long timeline. Dashboard tiles fade to grey one after another as days pass. On the right, a support-ticket counter ticks up.

**VOICEOVER:** The worst part — nobody's actually wrong. The refactor was clean. The review felt cosmetic. CI was green. Because your observability isn't part of your CI. Your dashboards, your SLOs, your conventions are sitting in Dynatrace, hoping the code keeps emitting what they expect.

**VOICEOVER:** So what if there was a better way? Something that caught the rename before it merged. That shipped the dashboard with the git tag. That blocked a bad release before it ever cut over. Today I'll show you.

---

## 1:30–2:30 · THE SOLUTION — THE FIVE PIECES

**DIAGRAM:** Animated schema — three stacked boxes labeled *code*, *semantic conventions*, *dashboards & SLOs*. A single git tag `v1.1.0` drops down and stamps all three.

**VOICEOVER:** The fix is one sentence. Your observability is part of your application — version it, tag it, and ship it with your app.

**VOICEOVER:** Five pieces make that work. Some of these are new — let me give you a one-liner on each.

**DIAGRAM:** Five numbered tiles on a slide. Each lights up as it's named: Weaver, dtctl, drift watcher, Argo (CD + Rollouts), Site Reliability Guardian.

**VOICEOVER:** **One. OpenTelemetry Weaver** — schema-as-code for OpenTelemetry. Your attributes live in a YAML registry; Weaver validates them in CI. Renames get flagged.

**VOICEOVER:** **Two. dtctl** — Dynatrace's CLI. Kubectl for your tenant. Dashboards, SLOs, guardians as YAML; `dtctl apply` syncs them.

**VOICEOVER:** **Three. A drift watcher** — a GitHub Action that diffs code against the Weaver registry and files a GitHub issue on drift.

**VOICEOVER:** **Four. Argo.** Argo CD — GitOps; reconciles the cluster from git. Argo Rollouts — canary controller; walks traffic 10, 50, 100 with an `AnalysisTemplate` between each step that can call any external check.

**VOICEOVER:** **Five. Site Reliability Guardian** — Dynatrace's YAML release gate. Evaluates your SLOs for ten minutes, returns pass, warn, or fail. That's the verdict Argo Rollouts waits on.

**DIAGRAM:** 2×2 tile grid titled "Agent skill stack" — dtctl skill · Dynatrace-for-AI · observability-agent-skills · observability-repair.

**VOICEOVER:** And Claude Code wears four skills when it resolves a drift ticket — dtctl native, Dynatrace-for-AI for reading, observability-agent-skills for writing, plus our project-local repair policy. That's what makes its fixes senior-grade.

---

## 2:30–2:50 · DEMO SETUP — CLUSTER + REPO

**SCREEN:** Split view. Left pane — terminal recording of `kubectl get ns` showing `istio-system`, `kgateway-system`, `dynatrace`, `opentelemetry-operator-system`, `argocd`, `argo-rollouts`, `otel-demo`. Right pane — the repo's file tree in VS Code.

**VOICEOVER:** Quick context. This is a small cluster — two worker nodes, eight gigs each. Cilium does the CNI. Istio is running in ambient mode — ztunnel as a DaemonSet, no sidecars — so east-west mTLS is a single pod per node. kgateway sits on top as the Gateway API implementation for north-south. Dynatrace Operator runs in Kubernetes-monitoring mode — Smartscape entities, no OneAgent. OpenTelemetry Operator handles the collector. Argo CD and Argo Rollouts own the app rollout. That whole stack fits in about six gigs.

**VOICEOVER:** Five folders in the repo — `weaver/`, `dtctl/`, `deploy/`, `.github/workflows/`, `skills/`. Let's ship a release.

---

## 2:50–4:25 · DEMO PART 1 — A CLEAN RELEASE VIA GITOPS (v1.1.0)

**SCREEN:** Split view — VS Code diff on the left, GitHub PR page on the right.

**VOICEOVER:** First scenario — a normal feature. I'm adding a `cart.size` attribute to the checkout service so the dashboard can show average items per order. Because I'm disciplined, three things change in the same PR.

**SCREEN:** Highlight three file changes in the PR — `checkout/main.py`, `weaver/registry/checkout.yaml`, `dtctl/dashboards/service-health.yaml`.

**VOICEOVER:** The code. The convention. The dashboard. Same commit. If any one of those is missing, CI will tell me.

**SCREEN:** GitHub PR "Checks" panel recording — all green.

```
✓ test
✓ weaver · registry check
✓ weaver · registry diff vs main (no breaking changes)
✓ dtctl · validate
```

**VOICEOVER:** Weaver's two checks green, dtctl validates, tests pass. Merge.

### Terminal — tag and push

```
$ git tag v1.1.0 && git push --tags
```

**SCREEN:** GitHub Actions log recording, speed-ramped 3×. Three lines scroll by.

```
✓ build image → ghcr.io/…/checkout:v1.1.0
✓ dtctl apply -f <(envsubst < dtctl/**)    # stamps APP_VERSION=v1.1.0
✓ bump deploy/helm/values.yaml → image.tag: v1.1.0   → git push
```

**VOICEOVER:** CI does two things. `dtctl apply` — pushes manifests stamped with `v1.1.0`. And a one-line commit bumping `image.tag` in `deploy/helm/values.yaml`. No `helm upgrade`. Argo takes it from here.

### Argo CD picks up the change

**SCREEN:** Argo CD web UI recording. The `otel-demo-light` Application card in focus. Sync badge flips `Synced` → `OutOfSync` → `Syncing` → `Synced` in about three seconds. Last-sync revision updates to the new commit SHA.

**VOICEOVER:** Argo CD's been polling this repo. CI pushed, Argo saw the drift, reconciled. That's "continuous delivery" in one screen.

### Argo Rollouts walks the canary

**SCREEN:** Argo Rollouts UI recording (`kubectl-argo-rollouts` dashboard). The `checkout` Rollout's canary strategy visualized — weight bar stepping 10% → 50% → 100% with green `srg-verdict` AnalysisRuns between each pause.

**VOICEOVER:** Now Argo Rollouts. Checkout's a Rollout, not a Deployment — canary strategy: 10, pause, analysis; 50, pause, analysis; 100. Each green AnalysisRun runs a Job that calls `dtctl get guardian-run` and reads the verdict. Both pass. Full cutover.

**SCREEN:** Dynatrace dashboard recording — new "Cart size distribution" tile fades in. Top-right version badge reads **v1.1.0**.

**VOICEOVER:** New tile's live. Version badge reads `v1.1.0` — which tells you, at a glance, exactly which release this dashboard is measuring. Hold that thought for Beat 3.

**SCREEN:** Dynatrace dashboard recording — new "Cart size distribution" tile fades in. Top-right version badge reads **v1.1.0**.

**VOICEOVER:** New tile — cart size distribution. And up in the corner, the dashboard tells you exactly which version of the app it's measuring. That badge is not decoration. It's the single most important thing on the screen. Because now — if your data gets weird, you can tell from one glance whether you're looking at `v1.1.0` or `v1.0.9`.

---

## 4:25–6:00 · DEMO PART 2 — SEE IT BREAK, LET CLAUDE FIX IT (v1.1.1)

**VOICEOVER:** Second scenario. Cleanup branch renames a span attribute — `customer.tier` → `customerTier`. Code only. No registry, no dashboard. Hotfix exception skips the review. Ships as `v1.1.1`.

**SCREEN:** Live `v1.1.1` dashboard recording — same dashboard from Beat 1. The **customer tier** filter is inert. The **errors by customer tier** table is empty. The **checkout-availability** SLO tile shows `—`. Zoom through each.

**VOICEOVER:** And this is what it does. Filter inert. Errors table empty. SLO blank — not burning, not healthy, just nothing. Because the SLI query filters on an attribute `v1.1.1` no longer emits. Nothing alarmed. It all just…stopped measuring.

**SCREEN:** GitHub Actions tab recording — new workflow run appears: `observability-watch`. Lower-third badge: *"Copilot-style observability reviewer."*

**VOICEOVER:** Good news. The moment that rename landed, `observability-watch` fired — the drift-watcher Action we talked about. Diffed the code against the Weaver registry, spotted the rename, filed an issue.

**SCREEN:** GitHub Issues tab recording — new issue appears at the top of the list.

```
#42 · Observability drift on refactor/camelcase-attrs (1 issue)
labels: observability-drift, needs-agent
```

**VOICEOVER:** The watcher files a ticket — a GitHub issue, assignable, closeable by a merge. That's the handoff to Claude.

**SCREEN:** Terminal recording — one-line handoff pasted from the issue body.

```
$ gh issue view 42 > /tmp/ticket.md
$ claude code --skill skills/observability-repair \
              --prompt "$(cat prompts/resolve-drift-ticket.md)
                        TICKET: $(cat /tmp/ticket.md)"
```

**VOICEOVER:** And this is where the skill stack earns its keep — all four skills loaded.

**SCREEN:** Claude Code terminal recording — tool calls scroll by (Read, Grep, Edit), then a unified diff is proposed.

### Claude's produced instrumentation — `checkout/main.py`

```python
from opentelemetry import trace
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("checkout.place_order") as span:
    # DEPRECATED — keep for one release so v1.1.0 dashboards still resolve.
    # Remove in v1.2.0.
    span.set_attribute("customer.tier", order.customer_tier)

    # NEW — target name going forward. Mirrors the registry entry.
    span.set_attribute("customerTier",  order.customer_tier)

    # Other required attributes per checkout.place_order convention.
    span.set_attribute("payment.method", order.payment_method)
    span.set_attribute("order.total_usd", order.total_usd)
    span.set_attribute("checkout.cart.size", len(order.items))
```

**VOICEOVER:** Look at the shape of that code. Both sides of the rename, with a "remove me in v1.2.0" comment. All four required attributes per the convention — because the semantic-conventions skill knows the span contract. That's what senior-grade agent output looks like.

### Claude's paired registry + dashboard changes

```yaml
# weaver/registry/checkout.yaml — deprecation overlay
- id: customer.tier
  deprecated: true
  deprecated_reason: "renamed to customerTier"
  brief: "DEPRECATED in v1.1.1 — use customerTier."

+ id: customerTier
  stability: experimental
  brief: "Customer subscription tier for the order."
```

```yaml
# dtctl/dashboards/service-health.yaml — coalesce during the overlap
filter: coalesce(customerTier, customer.tier) == $customer_tier
```

**VOICEOVER:** Registry, code, dashboard. Same commit. Same diff. Reviewable in one glance.

**SCREEN:** Stitched recording — `git push` → PR opens → CI checks go green → squash-merge → issue #42 auto-closes. Speed-ramped.

**SCREEN:** Same dashboard as before. The filter dropdown responds again. The errors table repopulates. The SLO tile flips from `—` back to a live percentage. Hold on the recovery.

**VOICEOVER:** Dashboard's alive. Filter works. Errors table populated. SLO measuring. One PR, three agents collaborating — Copilot files, Claude applies policy, humans review. Nothing goes to prod unchecked.

---

## 6:00–7:30 · DEMO PART 3 — ARGO + GUARDIAN STOP A BAD RELEASE (v1.1.2)

*(Host on sofa, voiceover continues.)*

**VOICEOVER:** Third scenario. This one's the scary one. The release is *valid* — Weaver's green, tests pass, everything merges. But the code has a regression: `payment.charge` got six hundred milliseconds slower. Nobody noticed. We tag it and ship it.

### Terminal

```
$ git tag v1.1.2 && git push --tags
```

**SCREEN:** GitHub Actions log recording. Three steps highlighted as they run.

```
✓ apply dtctl — Guardian "checkout-release-v1.1.2" registered
✓ bump deploy/helm/values.yaml → image.tag: v1.1.2
✓ Argo CD reconciled · Rollout "checkout" started (canary strategy)
```

**VOICEOVER:** Notice what CI did. Applied the Guardian — the YAML release gate scoped to `v1.1.2`. Bumped the tag. Pushed. Argo CD picked it up and started the canary. Nobody ran `helm upgrade`.

**SCREEN:** Argo Rollouts UI recording. The `checkout` Rollout at 10% canary weight. Two-minute pause, then an `AnalysisRun` named `srg-verdict` appears and starts polling.

**VOICEOVER:** Ten percent of traffic on v1.1.2 — that weight is on the `checkout-route` HTTPRoute, patched live by the Rollouts Gateway API plugin and served by kgateway. Soak, then the AnalysisRun fires — a Job that calls `dtctl get guardian-run` every thirty seconds and reads the verdict. Pass, promote. Fail, abort.

**SCREEN:** Dynatrace Site Reliability Guardian UI recording, side-by-side with a clock overlay ticking 0:00 → 10:00 (speed-ramped to ~30 seconds). Burn-rate objective goes red at minute four; p95 at minute seven.

### Guardian verdict

```
Guardian verdict: FAIL
  ✓ checkout-availability  99.4%  ≥ 99.0%
  ✗ frontend-p95-latency   312ms  > 200ms
  ✗ error-budget-burn      3.1    > 1.0
```

**SCREEN:** Back to the Argo Rollouts UI recording. The AnalysisRun flips to `Failed`. Rollout phase flips to `Degraded`. Traffic drains from the canary pods back to the stable pods.

**VOICEOVER:** AnalysisRun fails. The Rollout aborts on the spot. That ten percent of traffic on the bad version drains away — and critically, we never cut over. The stable pods on `v1.1.1` still own a hundred percent. There was no "bad release in production that we rolled back." There was a bad canary that never got promoted.

**SCREEN:** GitHub Actions log continues in the recording — `dtctl apply` re-stamps the manifests to `v1.1.1`, then a commit comment lands on the release commit with the Guardian's full objective table.

**VOICEOVER:** CI re-stamps the dashboards and SLOs back to v1.1.1, because the tenant state should match what's actually serving traffic. Then it posts a comment on the release commit — the objective that failed, by how much, and a link to the exact AnalysisRun in Argo. Zero pages. Zero humans. I'm in bed.

---

## 7:30–7:40 · THE BIGGER PICTURE

**ON-CAMERA:** Henrik on the sofa, ~10 seconds.

**VOICEOVER:** Conventions, dashboards, SLOs, release gates — all YAML, all versioned with your tag. Agents keep them in sync; humans review the PR. Monday workflow.

---

## 7:40–8:00 · WRAP-UP & CALL TO ACTION

**TITLE CARD:** Repo URL + three-line quickstart block.

**VOICEOVER:** Everything's in the repo — link in the description. Three `make` targets: `scenario-1` ships v1.1.0, `scenario-2` lets Copilot and Claude duet, `scenario-3` stages the regression.

**TITLE CARD:** Subscribe animation. End screen with next-episode thumbnail. Brief ON-CAMERA of Henrik over the top.

**VOICEOVER:** Tell me in the comments what your Guardian blocked. Subscribe if this is your kind of content. Next episode — Guardian verdict wired into a Slack approval flow, with the human-in-the-loop override. Thanks for watching, I'll see you in the next one. Bye!

---

# Production Notes

### Required Assets

Split by asset type so the editor knows what needs recording vs. building in post.

**Screen recordings (capture from live tools):**

- SR-1 · Dynatrace dashboard with all tiles showing "No data" (Pain)
- SR-2 · `kubectl get ns` output showing the five namespaces (Demo Setup)
- SR-3 · VS Code repo file tree alongside SR-2 (Demo Setup)
- SR-4 · GitHub PR "Checks" panel — all green (Beat 1)
- SR-5 · Terminal tagging `v1.1.0` + GitHub Actions log of `release.yml` (Beat 1)
- SR-6 · Argo CD UI — `otel-demo-light` Application card flipping Synced → OutOfSync → Syncing → Synced (Beat 1)
- SR-7 · Argo Rollouts UI — checkout canary stepping 10 → 50 → 100 with green `srg-verdict` AnalysisRuns (Beat 1)
- SR-8 · Dynatrace dashboard with new "Cart size distribution" tile + version badge `v1.1.0` (Beat 1)
- SR-9 · v1.1.1 dashboard — customer-tier filter inert, errors-by-tier table empty, SLO tile `—`. Zoom-ins on each (Beat 2)
- SR-10 · GitHub Actions tab with `observability-watch` run (Beat 2)
- SR-11 · GitHub Issue #42 body — drift table + embedded Claude prompt (Beat 2)
- SR-12 · Claude Code terminal — tool calls + proposed diff, with the `checkout/main.py` snippet held readable (Beat 2)
- SR-13 · Same dashboard as SR-9, recovering — filter responsive, table populated, SLO measuring (Beat 2)
- SR-14 · Dynatrace Guardian UI — clock overlay 0:00 → 10:00 speed-ramped (Beat 3)
- SR-15 · Guardian verdict screen: `fail` with per-objective outcomes (Beat 3)
- SR-16 · Argo Rollouts UI — AnalysisRun `srg-verdict` → `Failed`, Rollout `Degraded`, traffic draining (Beat 3)
- SR-17 · GitHub Actions + release-commit comment with Guardian evidence (Beat 3)
- SR-18 · Dashboard version badge flipping `v1.1.2` → `v1.1.1` (Beat 3)

**Diagrams / schemas (build in post):**

- D-1 · Three-box animation — code / conventions / dashboards stamped by a single `v1.1.0` tag (Solution)
- D-2 · Five numbered tiles slide (Weaver, dtctl, drift watcher, Argo CD+Rollouts, SRG) — each lighting up in turn (Solution)
- D-3 · 2×2 skill-stack grid — dtctl skill · Dynatrace-for-AI · observability-agent-skills · observability-repair (Solution)
- D-4 · `customer.tier` → `customerTier` code-diff overlay, anchored to a single broken dashboard tile (Pain)
- D-5 · Week-timeline animation — dashboard tiles decay one per day, support-ticket counter ticking up (Pain)

**On-camera shots:**

- OC-1 · Sofa, ~10–15 seconds over the title card (Opening)
- OC-2 · Sofa, ~10 seconds (Bigger Picture)
- OC-3 · Sofa, ~10 seconds overlaid on the end screen (Wrap-up)

**Title cards:**

- TC-1 · Opening title card — "Dashboards Are Part of Your API" with Observe & Resolve badge
- TC-2 · End screen — subscribe button + next-episode thumbnail
- TC-3 · Quickstart block — repo URL + three `make` targets

### Description Box Links

1. Companion repo — https://github.com/henrikrexed/observe-resolve-ep9-dtctl
2. dtctl — https://github.com/dynatrace-oss/dtctl
3. dtctl agent skill — https://github.com/dynatrace-oss/dtctl/blob/main/skills/dtctl/SKILL.md
4. Dynatrace for AI (plugin marketplace) — https://github.com/Dynatrace/dynatrace-for-ai
5. observability-agent-skills (OTel authoring pack) — https://github.com/henrikrexed/observability-agent-skills
6. OpenTelemetry Weaver — https://github.com/open-telemetry/weaver
7. OpenTelemetry demo (light) — https://github.com/henrikrexed/opentelemetry-demo-light
8. OpenTelemetry Operator — https://github.com/open-telemetry/opentelemetry-operator
9. Dynatrace Operator — https://github.com/Dynatrace/dynatrace-operator
10. Argo CD — https://argo-cd.readthedocs.io
11. Argo Rollouts — https://argoproj.github.io/argo-rollouts
12. Argo Rollouts Gateway API plugin — https://rollouts-plugin-trafficrouter-gatewayapi.readthedocs.io
13. Istio ambient mesh — https://istio.io/latest/docs/ambient/
14. kgateway — https://kgateway.dev
15. Cilium — https://cilium.io
16. Dynatrace Site Reliability Guardian docs — docs.dynatrace.com

### Audio / Music

Upbeat, modern tech-forward background music throughout — the standard Observe & Resolve bed. Steps down slightly during the five-piece explainer (1:30–2:30) so the definitions land cleanly. Re-enters mid-energy for Beat 1 when we're on screen recordings. Stays understated for Beat 2's repair sequence. Lifts for Beat 3's canary, crescendos briefly at the `FAIL` verdict (~6:55), then drops to a bed for the Bigger Picture and Wrap-up. Light success sting when the Argo Rollout aborts.

### On-Camera Segments

Same as the usual Observe & Resolve setup — Henrik on the sofa, natural light, conversational delivery. Voice-over runs across the whole episode. The viewer sees Henrik on camera only at the natural cutaway points:

- **~10–15 seconds** over the title card at 00:00 and the opening greeting
- **~8–10 seconds** at the Bigger Picture (7:30–7:40) — host speaks to camera, no diagram
- **~8–10 seconds** at the Wrap-up / CTA, overlaid on the end screen

Everywhere else, the screen alternates between:

- **Diagrams / schemas** (built in post) for the Pain explainer, the solution five-pieces tile animation, and the skill-stack grid
- **Screen recordings** of real tools for Beat 1 (Argo CD + Rollouts UIs, Dynatrace dashboard), Beat 2 (GitHub Issues + Claude Code terminal + dashboard recovery), Beat 3 (Guardian UI + Rollouts abort)

Estimated voice-over time: ~6:00. Diagram + recording time takes care of the rest.

### Key Differences from v9 Draft (2×8GB cluster + ambient mesh + kgateway)

The cluster shrank to 2 worker nodes × 8 GiB. To fit, the stack picked up Istio ambient (cheaper than sidecars) and kgateway (Gateway API). Argo Rollouts now drives the canary via the Gateway API plugin patching an HTTPRoute, not via SMI.

1. **Demo Setup VO** names the new pieces: *"Cilium CNI, Istio in ambient mode — ztunnel as a DaemonSet, no sidecars — and kgateway on top for north-south."*
2. **Beat 3 VO updated.** The canary's 10% weight is now stated as being on an HTTPRoute, *"patched live by the Rollouts Gateway API plugin and served by kgateway."* Keeps the Guardian mechanic identical but makes the plumbing precise.
3. **`deploy.sh` grew** by three phases — Gateway API CRDs, Istio ambient (`istioctl install --set profile=ambient`), and kgateway (via Helm).
4. **Resource ceilings trimmed everywhere** — ActiveGate to 512 MiB, OTel Collector down to 1 replica at 512 MiB, otel-demo services nearly halved, Argo CD scaled dex + applicationset to zero. Peak cluster use drops to ~2.8 vCPU / ~5.9 GiB — fits 2×8 GiB with ~2 GiB memory headroom.
5. **`rollout.yaml` switched trafficRouting** from SMI to `plugins.argoproj-labs/gatewayAPI`. New files: `deploy/rollouts/plugin-config.yaml` (ConfigMap) and `deploy/rollouts/rbac-gateway-api.yaml` (HTTPRoute patch permissions).
6. **New manifests** — `demo-app/manifests/gateway.yaml` (Gateway resource with `gatewayClassName: kgateway`) and `demo-app/manifests/httproute-checkout.yaml` (baseline weights 100/0, patched by Rollouts at runtime).
7. **Cilium compatibility noted** in `demo-app/README.md` — ambient mesh requires `cni.exclusive: false` and `socketLB.hostNamespaceOnly: true`, defaults since Cilium 1.16.

---

### Earlier — Differences from v8 Draft (format rebuild)

v8 still read like a short film — "Cut to Henrik at a dim desk," "Jump to dashboard," "SFX: pager vibration," "smirking," "leans in." That's not how Observe & Resolve is shot. This pass rewrites the whole SCREEN CUE layer to match Henrik's actual format.

1. **SCREEN CUE taxonomy.** Replaced the single `SCREEN CUE:` label with four explicit prefixes — `SCREEN:` for screen recordings, `DIAGRAM:` for concept schemas, `TITLE CARD:` for text slides, `ON-CAMERA:` for the sofa cutaways. Editor can now tell at a glance whether a beat needs footage or a post-production asset.
2. **Cinematic direction stripped.** No more "Cut to," "Jump to," "Smash cut," "SFX," "smirks," "leans in." The host is implicitly on the sofa throughout; screen alternates between diagrams and recordings; on-camera frames are called out only where they actually appear.
3. **Pain rewritten in Henrik's peer-to-peer voice.** Replaced the 2 AM pager narrative with a direct rhetorical opener — *"Think about this. How many of you have opened a dashboard that should have data and gotten 'No data' tiles? Raise your hand. I see you."* — modeled on the Smartscape V2 Pain beat. Ends with the signature "So what if there was a better way?" bridge.
4. **Required Assets reorganized** by type — Screen Recordings (SR-1…18), Diagrams (D-1…5), On-Camera (OC-1…3), Title Cards (TC-1…3) — so the editor can batch-produce each asset class.
5. **On-Camera Segments note rewritten** to reflect the sofa setup, not a dim-desk "pager" mise-en-scène. On-camera time stays at ~30 seconds total (opener + Bigger Picture + Wrap-up).

---

### Earlier — Differences from v7 Draft (term primers)

Added explicit one-sentence primers for every new concept before or as it first appears. Viewers unfamiliar with Weaver, dtctl, the drift watcher, Argo, or the Site Reliability Guardian can still follow along.

1. **Solution section reshaped as a five-piece primer.** Each of Weaver, dtctl, drift watcher, Argo (CD + Rollouts), and Site Reliability Guardian gets a single-sentence "what it is" before the "what it does for us" in the enumerate slide.
2. **Inline anchors in each beat.** Beat 1's PR checks call out Weaver's two steps; the terminal narration names dtctl and Argo by role when each first appears on camera. Beat 2 reminds viewers that the watcher is a GitHub Action in the repo. Beat 3 anchors the Guardian ("the YAML release gate") and the AnalysisRun ("a Kubernetes object that runs a query and emits pass/fail/inconclusive") right when they're visible.
3. **Overall VO tightened.** Pain, Beat 2, Bigger Picture, and Wrap-up cut to fund the explanations. Total spoken word count ≈ 844 — in line with the Smartscape V2 reference script that landed at 8:00 exact. All nine section windows have 25–35 seconds of visual/hold time budget remaining, which is what makes an 8:00 demo feel unhurried.
4. **Section headers aligned with no gaps.** Solution now runs 1:10–2:25 (was 1:20–2:30), Demo Setup 2:25–2:50, Demo Part 1 2:50–4:25 — removes the 5–10 second dead air that slipped in during the v7 pass.

---

### Earlier — Differences from v6 Draft (Argo promotion)

Argo moves from background plumbing to a named piece of the workflow:

1. **Solution section now has FIVE pieces** (was four). A numbered explainer slide lights up each piece in turn — Weaver, dtctl, Copilot watcher, **Argo (CD + Rollouts)**, SRG — and the voice-over gives Argo a full paragraph explaining both layers (CD = reconciliation from git; Rollouts = canary with `AnalysisTemplate` calling the Guardian).
2. **Beat 1 expanded from 1:15 to 1:25** with two dedicated Argo scenes: the Argo CD UI reconciling the `otel-demo-light` Application, then the Argo Rollouts UI visually stepping the `checkout` canary 10% → 50% → 100% with green `srg-verdict` AnalysisRuns between each step. Viewer *sees* the canary, not just hears about it.
3. **Pain and Beat 2 tightened** 5–10 seconds each to fund the Argo expansion without blowing the 8:00 runtime.
4. **Required Screen Captures** renumbered and expanded from 24 to 24 entries that explicitly include the Argo CD UI sync animation and the Rollouts canary walk (Beat 1), plus the aborted AnalysisRun / draining canary (Beat 3).
5. **The "two tools, one job" mental model stays** — CI does dtctl-apply plus a one-line tag bump; Argo owns the cutover; Guardian owns the gate. No human runs `helm upgrade`.

---

### Earlier — Differences from v5 Draft

This version wires in the cluster topology (Dynatrace Operator + OpenTelemetry Operator) and Argo CD / Argo Rollouts as the rollout engine:

1. **Demo Setup section** now opens with a `kubectl get ns` split showing three operators — `dynatrace`, `opentelemetry-operator-system`, `argocd`, `argo-rollouts` — plus `otel-demo`. VOICEOVER calls out "Kubernetes monitoring mode — no OneAgent."
2. **Beat 1 rewritten as pure GitOps.** `release.yml` no longer runs `helm upgrade` directly. It bumps `image.tag` in `deploy/helm/values.yaml`, pushes, and Argo CD reconciles. We cut to the Argo Rollouts UI showing the canary progress (10% → 50% → 100%) with AnalysisRuns between steps. This plants the seed for Beat 3's payoff.
3. **Beat 3 is now "Argo + Guardian stop a bad release."** The SRG is invoked via an `AnalysisTemplate` in `deploy/rollouts/analysistemplate-srg.yaml` that polls `dtctl get guardian-run`. On fail, the Rollout **aborts at 10% canary** — traffic never cuts over. Key framing change: this is not a "rollback after prod failure"; it's a "canary that never got promoted." More honest and more impressive.
4. **No more `helm rollback` on camera.** The recovery is Argo draining the canary plus CI re-stamping dtctl manifests.
5. **Timing grid shifted** to accommodate the deeper Beat 3 (1:15 → 1:30). Pain tightened 5s, Solution 5s, Beat 1 5s, Beat 2 5s; Wrap-up gained 5s.
6. **Description Box Links + Required Screen Captures** expanded to include Argo CD, Argo Rollouts, the two operators, and three new screen captures (Argo CD UI synced, Rollouts canary steps, AnalysisRun failure).

---

### Earlier — Differences from v4 Draft

This version adds the skill stack and makes the Beat 2 failure visible on screen:

1. **Solution section** now introduces the four-skill stack Claude wears: dtctl's own agent skill (install: `dtctl skills install`), Dynatrace-for-AI (Claude plugin marketplace for *reading* observability), observability-agent-skills (npm-installable pack for *writing* OpenTelemetry code), and the project-local observability-repair policy. Explainer slide added as a 2×2 grid.
2. **Beat 2 expanded from 1:40 to 2:00.** New content: the `v1.1.1` dashboard visibly failing before the ticket fires — customer-tier filter inert, errors-by-tier table empty, SLO tile blank — so viewers *see* the cost of drift. After the resolver merge, we cut back to the dashboard coming back to life (filter responsive, table populated, SLO measuring). Recovery is the payoff.
3. **Produced instrumentation on screen.** Claude's proposed diff now shows the actual `checkout/main.py` snippet long enough to read, demonstrating what correct OTel authoring looks like when the observability-agent-skills pack is loaded (semantic-conventions-compliant, deprecation comment, all required attributes, PII considerations).
4. **Beat 3 tightened from 1:30 to 1:15.** Consolidated the verdict + rollback + re-stamp + commit comment into one shot; removed the "Zero pages, zero humans" repetition.
5. **Bigger Picture tightened from 0:15 to 0:10**, Pain from 1:30 to 1:25 — reclaimed 20 seconds to fund Beat 2's visible failure + recovery sequence. Total runtime stays exactly 8:00.
6. `agent-observability` (agents observing themselves) is now marked an optional bonus in the repo and is NOT referenced in the script. Earlier framing was wrong — the four-skill stack is about agents *writing* correct observability code, not observing themselves.
7. Description Box Links expanded from 6 to 8 entries to cover all four skill sources plus the Guardian docs.
8. Required Screen Captures grew from 18 to 21 to call out the visible failure + recovery shots in Beat 2 and the skill-stack slide in the Solution.
