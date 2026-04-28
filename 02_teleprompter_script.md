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
| The Pain Point | 1:20 |
| The Solution — The Five Pieces (with primers) | 1:00 |
| dtctl Command Cheat Sheet | 0:25 |
| Demo Setup — Architecture Explained | 0:30 |
| Demo Part 1 — A Clean Release via GitOps (v1.1.0) | 1:30 |
| Demo Part 2 — See It Break, Let Claude Fix It (v1.1.1) | 1:45 |
| Demo Part 3 — Argo + Guardian Stop a Bad Release (v1.1.2) | 1:25 |
| The Bigger Picture | 0:10 |
| Wrap-up & CTA | 0:20 |
| **TOTAL** | **8:30** |

---

## 00:00–00:05 · OPENING / COLD START

**TITLE CARD:** Animated title card with upbeat music. *"Dashboards Are Part of Your API"* slides in. Dynatrace logo. Episode badge: "Observe & Resolve."

**ON-CAMERA:** Henrik on the sofa, casual framing, ~10 seconds.

**VOICEOVER:** Hey everyone, welcome back to "Observe & Resolve," your go-to series for troubleshooting and analyzing cloud-native technologies. I'm Henrik Rexed, and today we're going to talk about the quiet, expensive way your observability lies to you — and how to stop it.

---

## 00:05–1:30 · THE PAIN POINT

**VOICEOVER:** Quick question. How many of you have opened a Dynatrace dashboard that *should* have data — and instead you're staring at "No data" tiles? The app is running fine. Metrics are flowing. But your dashboard? Dead. Raise your hand if this sounds familiar. Yeah, I see you. I've been there more times than I'd like to admit.

**VOICEOVER:** Here's the context that makes this hurt even more. Every signal on this dashboard comes from OpenTelemetry SDKs we manually instrumented. No OneAgent magic. No auto-discovery. Our code owns every single attribute name. Which means when something breaks? It's on us.

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

## 2:30–2:55 · dtctl COMMAND CHEAT SHEET

**DIAGRAM:** Full-screen command reference card. Clean typography, six commands in two columns with one-line descriptions. Title: "dtctl — Your Observability Control Plane"

```
┌─ dtctl Command Reference ─────────────────────────────────────┐
│                                                                │
│  # Authentication                                              │
│  dtctl auth login              Connect to your Dynatrace tenant│
│  dtctl auth verify             Confirm credentials are valid   │
│                                                                │
│  # Query Live Telemetry                                        │
│  dtctl exec query "DQL"        Run DQL, get JSON back          │
│                                                                │
│  # Manage Resources (GitOps-style)                             │
│  dtctl get dashboards          List all dashboards             │
│  dtctl describe dashboard <id> Show full YAML definition       │
│  dtctl apply -f <file|dir>     Sync YAML to tenant (idempotent)│
│  dtctl diff -f <file>          Preview changes before apply    │
│                                                                │
│  # Site Reliability Guardian                                   │
│  dtctl apply -f guardian.yaml  Register a release gate         │
│  dtctl get guardian-run \      Read the verdict (pass/warn/fail)
│    --guardian <name> --latest                                  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**VOICEOVER:** Before we dive into the demo, here's your dtctl cheat sheet. Screenshot this if you want. Three categories: auth, query, and resource management. The pattern is kubectl-like — `get`, `describe`, `apply`, `diff`. The game-changer is `apply` — it's idempotent, version-aware, and works on entire directories. Run it twice, get the same result. That's what makes it safe to call from CI.

**VOICEOVER:** One pro tip before we move on. Always run `dtctl diff` before `apply` in production. Shows you exactly what's about to change. No surprises. I'll show you this pattern live in Beat 1.

---

## 2:55–3:25 · DEMO SETUP — ARCHITECTURE EXPLAINED

**DIAGRAM:** Architecture diagram - three layers stacked vertically. Bottom: "Kubernetes Cluster (2 nodes, Cilium CNI)". Middle: Four operator boxes side-by-side labeled "Dynatrace Operator (K8s monitoring)", "OTel Operator (collector)", "Argo CD (GitOps)", "Argo Rollouts (canary)". Top: "otel-demo app" with OTLP arrows flowing to "Dynatrace tenant". Highlight the "no OneAgent" callout.

**VOICEOVER:** Here's the architecture. Small cluster — two worker nodes, eight gigs each. Four operators running. Let me explain why each one matters.

**VOICEOVER:** Dynatrace Operator in Kubernetes-monitoring mode. That means Smartscape sees the cluster topology — pods, nodes, workloads — but we're NOT running OneAgent. No auto-instrumentation. This is 100% manual OpenTelemetry, which is exactly why drift can bite us.

**VOICEOVER:** OpenTelemetry Operator manages the collector. Our app sends OTLP; the collector forwards to Dynatrace. Standard pattern.

**VOICEOVER:** Argo CD handles GitOps. It watches this repo. When we bump a Helm value and push, Argo reconciles the cluster state to match. No one runs `kubectl apply` by hand.

**VOICEOVER:** And Argo Rollouts gives us canary deployments with analysis steps. That's how we hook the Site Reliability Guardian into the release path. Ten percent canary, pause, ask the Guardian "is this safe?" If it says fail, the canary never promotes. We'll see this pay off in Beat 3.

**SCREEN:** Split view. Left pane — terminal recording of `kubectl get ns` showing the five namespaces. Right pane — the repo's file tree in VS Code, folders expanded one level.

**VOICEOVER:** The repo structure: `weaver/registry/` — semantic conventions. `dtctl/` — dashboards, SLOs, guardians. `deploy/` — Helm charts and Rollout manifests. `.github/workflows/` — CI that ties it all together. `skills/` — the agent policy that keeps Claude from making junior mistakes. Everything versioned together. Let's ship a release and watch the pipeline do its thing.

---

## 3:25–4:55 · DEMO PART 1 — A CLEAN RELEASE VIA GITOPS (v1.1.0)

**SCREEN:** Split view — VS Code diff on the left, GitHub PR page on the right.

**VOICEOVER:** First scenario — the happy path. I'm adding a new metric: `cart.size` on the checkout span. Simple feature. Product wants to see average items per order on the dashboard. Straightforward, right?

**VOICEOVER:** Here's the discipline that saves you later. Three files change in the same PR. Watch for this pattern.

**SCREEN:** Highlight three file changes in the PR — `checkout/main.py`, `weaver/registry/checkout.yaml`, `dtctl/dashboards/service-health.yaml`. Zoom in on each for two seconds as it's named.

**VOICEOVER:** One. The code — `checkout/main.py` — where we emit the span attribute. Two. The Weaver registry — `weaver/registry/checkout.yaml` — where we declare the attribute's type, stability, and meaning. Three. The dashboard — `dtctl/dashboards/service-health.yaml` — where we query it. Code, schema, query. Same commit. Same PR. If I forget one, CI catches it. This is the contract that prevents drift.

**SCREEN:** GitHub PR "Checks" panel recording — all green. Each check appears one by one with a green checkmark animation.

```
✓ test
✓ weaver · registry check
✓ weaver · registry diff vs main (no breaking changes)
✓ dtctl · validate
```

**VOICEOVER:** Now watch the CI checks. Four gates. Tests pass — that's table stakes. Weaver registry check — validates every attribute has a type, stability level, and description. Weaver registry diff — compares against main and blocks breaking changes like type changes or attribute removals. And dtctl validate — parses every dashboard and SLO YAML to catch syntax errors before they hit the tenant.

**VOICEOVER:** Pro tip number one: that diff check is your safety net. If someone tries to delete a stable attribute, CI fails the PR. No production surprises. Merge.

### Terminal — tag and push

```
$ git tag v1.1.0 && git push --tags
```

**SCREEN:** GitHub Actions log recording, speed-ramped 2.5×. Three steps highlighted as they execute.

```
✓ build image → ghcr.io/…/checkout:v1.1.0
✓ dtctl apply -f dtctl/                     # dashboards, workflows, guardian
✓ dtctl create slo -f dtctl/slos/           # upsert long-lived SLOs
✓ bump deploy/helm/values.yaml → image.tag: v1.1.0   → git push
```

**VOICEOVER:** Tag `v1.1.0` and push. Watch what the release workflow does. It's a four-step dance.

**VOICEOVER:** Step one: build and push the container image. Step two: run `dtctl apply` on dashboards, workflows, and the guardian. The guardian is the only resource that carries a version in its name — because it's a release gate, one per deploy. Dashboards and SLOs? They're long-lived. One dashboard, one set of SLOs, shared across all releases.

**VOICEOVER:** Pro tip number two: don't create a dashboard per release. After a year of weekly releases, you'd have fifty orphaned dashboards. Instead, make your SLOs and dashboards version-agnostic. Use a dashboard variable to filter by release when you need to. The Guardian is your per-release gate — that's where the version belongs.

**VOICEOVER:** Step three: bump the Helm values file to point at `image.tag: v1.1.0`, commit, and push. Notice what we didn't do? We didn't run `helm upgrade`. That's Argo's job now.

### Argo CD picks up the change

**SCREEN:** Argo CD web UI recording. The `otel-demo-light` Application card in focus. Sync badge flips `Synced` → `OutOfSync` → `Syncing` → `Synced` in about three seconds. Last-sync revision updates to the new commit SHA. Slow zoom on the revision SHA.

**VOICEOVER:** Argo CD's been polling the repo every three minutes. It sees the values file changed, marks the app out-of-sync, and reconciles. Watch the sync status flip. Three seconds later — synced. GitOps in action. CI declares intent, Argo enforces reality.

### Argo Rollouts walks the canary

**SCREEN:** Argo Rollouts UI recording (`kubectl-argo-rollouts` dashboard). The `checkout` Rollout's canary strategy visualized — weight bar stepping 10% → 50% → 100% with green `srg-verdict` AnalysisRuns between each pause. Linger on each pause for emphasis.

**VOICEOVER:** Here's where it gets interesting. Checkout isn't a regular Deployment — it's a Rollout. Canary strategy. Ten percent canary pods, ninety percent stable. Pause. Run an AnalysisRun. If it passes, promote to fifty percent. Pause. Another AnalysisRun. Pass? Full cutover.

**VOICEOVER:** What's that AnalysisRun doing? It's running a Kubernetes Job that calls `dtctl get guardian-run --guardian checkout-release-guardian --latest` and parses the verdict. Pass means promote. Fail means abort. That's the hook between Argo and the Site Reliability Guardian. We'll see it save us in Beat 3.

**VOICEOVER:** Both analyses pass. Full cutover. Canary becomes stable. Let's check the dashboard.

### The version variable — filter by release, live

**SCREEN:** Dynatrace dashboard recording — new "Checkout PlaceOrder count" tile fades in. Top-left shows an "Active Release" tile reading the live version. A dropdown labeled "Release version" is visible at the top of the dashboard.

**VOICEOVER:** New tile is live. Checkout PlaceOrder counts, just like Product asked for. But pause here for a second. Look at this dashboard. See that "Active Release" tile? It's not hardcoded. It's a live DQL query that reads `service.version` from the spans flowing right now. Whatever version is serving traffic — that's what it shows. No stamping. No templating. Just live data.

**VOICEOVER:** And see that dropdown at the top? "Release version." Click it, you get every version Dynatrace has seen in the last two hours. Select one, and every tile on this dashboard filters to just that release. Leave it on "all" and you see everything. This is how you debug a canary — select the canary version, compare with the stable one. One dashboard, multiple views.

**VOICEOVER:** Pro tip number three: don't bake your version into dashboards. Query it live. Dynatrace already knows which version is running — through `service.version`, through `app.kubernetes.io/version` labels, through SDLC events. Use a dashboard variable to let users filter. When you're debugging at 2 AM, you pick the version from the dropdown, not from a pile of fifty dashboards.

---

## 4:55–6:40 · DEMO PART 2 — SEE IT BREAK, LET CLAUDE FIX IT (v1.1.1)

**VOICEOVER:** Second scenario. This is the one that happens every week in real life. Someone's refactoring for consistency. They see `customer.tier` with a dot and think "we standardized on camelCase last quarter." So they rename it to `customerTier`. Code looks cleaner. Tests pass. It's a two-line change. Hotfix path, skips the full PR review, ships as `v1.1.1`.

**VOICEOVER:** And then…

**SCREEN:** Live `v1.1.1` dashboard recording — same dashboard from Beat 1. Slow zoom on three broken elements as each is named. The **customer tier** filter dropdown (clicking it shows "No data"). The **errors by customer tier** table (completely empty). The **checkout-availability** SLO tile (shows `—` instead of a percentage).

**VOICEOVER:** …this. The customer tier filter? Inert. Click it, nothing. The errors-by-tier breakdown table? Empty. The checkout availability SLO? Just a dash. Not burning, not healthy, not measuring at all.

**VOICEOVER:** Here's why this is terrifying. The dashboard didn't throw an error. It didn't send an alert. It just silently stopped measuring. The SLI query is filtering on `customer.tier`, but `v1.1.1` only emits `customerTier`. Zero events match. Zero divided by zero is `—`. And nobody noticed for hours because nothing broke loudly.

**SCREEN:** GitHub Actions tab recording — new workflow run appears with a yellow warning badge: `observability-watch`. Lower-third banner: *"Post-merge drift detector"*.

**VOICEOVER:** But here's the safety net. Ten minutes after that rename merged, `observability-watch` fired — a scheduled GitHub Action that runs every hour. It does one thing: diffs every span attribute in the code against the Weaver registry baseline. Found one? `customer.tier` exists in the registry. `customerTier` doesn't. Drift detected. File a ticket.

**SCREEN:** GitHub Issues tab recording — new issue appears at the top of the list, auto-labeled.

```
#42 · Observability drift detected on main
branch: main
labels: observability-drift, needs-repair, priority:high
attributes affected: customer.tier → customerTier (checkout service)
dashboards impacted: 2
SLOs impacted: 1
```

**VOICEOVER:** The issue body is structured. Which attribute drifted, what it was renamed to, which dashboards query it, which SLOs depend on it. Everything an agent needs to fix it. And notice the label: `needs-repair`. That's the trigger for the agent workflow.

**VOICEOVER:** Pro tip number four: make your drift detector loud. We label it high-priority and block deploys to staging until the ticket closes. Drift in production is expensive. Drift caught in the next commit is cheap.

**SCREEN:** Terminal recording — command shown as if typed live, character by character.

```
$ gh issue view 42 > /tmp/ticket.md
$ claude code \
    --skill skills/observability-repair \
    --skill @dynatrace/observability-agent-skills \
    --skill @dynatrace/dynatrace-for-ai \
    --prompt "$(cat prompts/resolve-drift-ticket.md)
              TICKET: $(cat /tmp/ticket.md)"
```

**VOICEOVER:** Here's the handoff. Pull the ticket content with the GitHub CLI. Pass it to Claude Code with three skills loaded. The observability-repair skill — that's our repo-specific policy, the golden rule: every migration is a two-release operation. The observability-agent-skills pack — teaches Claude how to write correct OpenTelemetry instrumentation. And dynatrace-for-ai — gives it the vocabulary to read DQL and reason about dashboards.

**VOICEOVER:** This isn't just "ask ChatGPT to fix it." This is a senior-grade agent wearing domain skills. Watch what it produces.

**SCREEN:** Claude Code terminal recording — tool calls scroll by with labels overlaid: Read (checkout/main.py), Grep (customer.tier across dtctl/), Read (weaver/registry/checkout.yaml), Read (dtctl/dashboards/service-health.yaml). Then a unified diff appears.

**VOICEOVER:** It reads the code. Greps for every place the attribute is referenced. Reads the registry and the dashboard. Then it produces a three-file diff. Let's walk through what makes this output correct.

### Claude's produced instrumentation — `checkout/main.py`

**SCREEN:** Split-screen code view. Left: the broken v1.1.1 code (only `customerTier`). Right: Claude's proposed fix. Highlight each section as it's discussed.

```python
from opentelemetry import trace
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("checkout.place_order") as span:
    # DEPRECATED in v1.1.2 — keeping for one release cycle so v1.1.0
    # dashboards still resolve. Remove in v1.2.0 after confirming all
    # dashboards have migrated to customerTier.
    span.set_attribute("customer.tier", order.customer_tier)

    # PRIMARY as of v1.1.2 — target name going forward.
    # Mirrors the Weaver registry entry.
    span.set_attribute("customerTier", order.customer_tier)

    # Other required attributes per checkout.place_order convention
    span.set_attribute("payment.method", order.payment_method)
    span.set_attribute("order.total_usd", order.total_usd)
    span.set_attribute("checkout.cart.size", len(order.items))
```

**VOICEOVER:** Look at this code. This is what separates a junior fix from a senior fix. Claude didn't just add back the old attribute. It emits both. Old and new. Same span. For one full release cycle.

**VOICEOVER:** Why? Because `v1.1.0` dashboards in the wild are still querying `customer.tier`. If we only emit `customerTier`, those dashboards stay broken. By emitting both for one release, we give ourselves time to migrate every query, confirm they're all switched over, then remove the deprecated name in `v1.2.0`. This is the two-release migration rule — and it's encoded in the observability-repair skill.

**VOICEOVER:** Notice the comment precision. It doesn't just say "deprecated." It says when it was deprecated, why we're keeping it, and when it's safe to remove. Six months from now, whoever's cleaning up tech debt will thank you.

**VOICEOVER:** Pro tip number five: when you rename a telemetry attribute, never do it in one shot. Emit both for one release. Update queries. Verify. Then delete the old one. Costs you one deploy cycle, saves you hours of dashboard archaeology.

### Claude's paired registry + dashboard changes

**SCREEN:** Split three-panel view. Top: `weaver/registry/checkout.yaml` diff. Middle: `checkout/main.py` diff (from previous frame). Bottom: `dtctl/dashboards/service-health.yaml` diff. All three synchronized.

```yaml
# weaver/registry/checkout.yaml — deprecation overlay, not deletion

  - id: customer.tier
    type: string
    stability: stable                    # ← stays stable, doesn't regress
+   deprecated: true
+   deprecated_reason: "Renamed to customerTier for camelCase consistency.
+                       Remove in v1.2.0 after dashboard migration."
    brief: "DEPRECATED in v1.1.2 — use customerTier."

+ - id: customerTier
+   type: string
+   stability: experimental              # ← new names start experimental
+   brief: "Customer subscription tier (free, pro, enterprise)."
```

**VOICEOVER:** Registry changes. Notice what Claude did NOT do. It didn't delete `customer.tier`. It marked it deprecated with a reason and a removal target. The old attribute stays in the schema as `stable` — because we're still emitting it for one release. The new attribute starts as `experimental` — because it hasn't been in production for a full cycle yet.

**VOICEOVER:** This is Weaver's stability contract. Experimental means "might change." Stable means "safe to depend on." You can't go from experimental to stable in one PR. You have to prove it in production first. That's the guard rail that prevents you from making a bad name choice and then being stuck with it forever.

```yaml
# dtctl/dashboards/service-health.yaml — coalesce during the overlap

  # Customer tier filter
- filter: customer.tier == $customer_tier
+ filter: coalesce(customerTier, customer.tier) == $customer_tier

  # Errors by tier table
  summarize count = count(),
            by: {
-             tier: customer.tier
+             tier: coalesce(customerTier, customer.tier)
            }
```

**VOICEOVER:** Dashboard changes. The DQL queries now use `coalesce`. Try the new name first. If it's null, fall back to the old name. This works during the overlap window when some spans emit both, some emit only the old name, and eventually all emit only the new name. One query handles all three states.

**VOICEOVER:** Pro tip number six: `coalesce` is your friend during migrations. Lets you write one query that works across three versions. No feature flags, no conditional logic, just SQL semantics.

**VOICEOVER:** Registry, code, dashboard. Three files. Same commit. Same PR. Reviewable in one glance. This is the contract that prevents drift.

**SCREEN:** Stitched recording — `git push` → PR opens → CI checks go green → squash-merge → issue #42 auto-closes. Speed-ramped.

**SCREEN:** Same dashboard as before. The filter dropdown responds again. The errors table repopulates. The SLO tile flips from `—` back to a live percentage. Hold on the recovery.

**VOICEOVER:** Dashboard's alive. Filter works. Errors table populated. SLO measuring. One PR, three agents collaborating — Copilot files, Claude applies policy, humans review. Nothing goes to prod unchecked.

---

## 6:40–8:05 · DEMO PART 3 — ARGO + GUARDIAN STOP A BAD RELEASE (v1.1.2)

**VOICEOVER:** Third scenario. This is the one that wakes you up at 3 AM. The PR looks clean. All the disciplines from Beat 1 — code, registry, dashboard in the same commit. Weaver checks green. Tests pass. No drift. Everything by the book. Merges, ships as `v1.1.2`.

**VOICEOVER:** But buried in the code is a regression. Someone refactored the payment service's database connection pool. Thought they were optimizing. Instead, `payment.charge` got six hundred milliseconds slower. It didn't fail. It's just slow. And nobody caught it in the PR review because there's no test that says "this method must complete in under 200 milliseconds."

**VOICEOVER:** This is the scenario that terrifies me. Not the broken deploy that crashes loudly. The slow deploy that silently degrades user experience for hours before someone notices.

### Terminal

```
$ git tag v1.1.2 && git push --tags
```

**SCREEN:** GitHub Actions log recording. Three steps highlighted as they run, with line-by-line reveals.

```
✓ apply dtctl — Guardian "checkout-release-v1.1.2" registered
  ├─ 3 objectives: checkout-availability ≥99%, frontend-p95 <200ms, error-budget-burn <1.0
  └─ evaluation window: 10 minutes starting now

✓ bump deploy/helm/values.yaml → image.tag: v1.1.2

✓ Argo CD reconciled · Rollout "checkout" started (canary strategy)
```

**VOICEOVER:** Watch what CI does. Step one: `dtctl apply` registers the Guardian. That's the release gate for `v1.1.2` specifically. Three objectives — availability stays above 99%, p95 latency stays under 200 milliseconds, error budget burn rate stays under 1.0. Ten-minute evaluation window starting now.

**VOICEOVER:** Step two: bump the tag. Step three: Argo CD picks it up and starts the Rollout. We're live. Canary is deploying.

**SCREEN:** Argo Rollouts UI recording. The `checkout` Rollout at 10% canary weight. Replica count shows 1 canary pod, 2 stable pods. Two-minute soak timer counting down. Then an `AnalysisRun` named `srg-verdict` appears and starts polling every 30 seconds.

**VOICEOVER:** Argo Rollouts promotes one canary pod. Ten percent of traffic hitting `v1.1.2`. Ninety percent still on `v1.1.1`. Two-minute soak — let the new code run under real load. Then the AnalysisRun fires.

**VOICEOVER:** What's that AnalysisRun doing? It's a Kubernetes Job running in the cluster. Every thirty seconds it calls `dtctl get guardian-run --guardian checkout-release-v1.1.2 --latest` and reads the verdict. Pending? Keep waiting. Pass? Promote to 50%. Fail? Abort and drain the canary.

**VOICEOVER:** Let's watch the Guardian evaluate.

**SCREEN:** Dynatrace Site Reliability Guardian UI recording, side-by-side with a clock overlay ticking 0:00 → 10:00 (speed-ramped to ~30 seconds of screen time). Objective tiles light up as they're evaluated. Availability stays green. p95 latency goes yellow at minute 3, red at minute 5. Error budget burn rate goes yellow at minute 4, red at minute 6.

**VOICEOVER:** Guardian's running its queries. Availability — green, 99.4%. Good. p95 latency — starts at 180 milliseconds. Then 205. Then 280. Red at minute five. Error budget burn rate — starts at 0.8, climbs to 2.1, red at minute six. Two objectives failing. Verdict: fail.

### Guardian verdict — and the abort

**SCREEN:** Full-screen terminal output showing the Guardian verdict, styled like a CI log.

```
┌─ Site Reliability Guardian Verdict ─────────────────────────────┐
│                                                                  │
│  Guardian: checkout-release-v1.1.2                               │
│  Evaluation: 10:00 minutes                                       │
│  Result: FAIL                                                    │
│                                                                  │
│  Objectives:                                                     │
│    ✓ checkout-availability    99.4%    ≥ 99.0%    PASS          │
│    ✗ frontend-p95-latency     312ms    < 200ms    FAIL          │
│    ✗ error-budget-burn        3.1      < 1.0      FAIL          │
│                                                                  │
│  Recommendation: DO NOT PROMOTE                                  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**VOICEOVER:** Verdict comes back. Two objectives red. Fail. Do not promote.

**SCREEN:** Back to the Argo Rollouts UI recording. The `srg-verdict` AnalysisRun tile flips from `Running` → `Failed` (red). Rollout phase flips from `Paused` → `Degraded`. Traffic weight bar animates — canary weight drains from 10% back to 0%. Canary pod count drops from 1 to 0.

**VOICEOVER:** Watch what happens. The AnalysisRun reads that verdict and marks itself `Failed`. Argo Rollouts sees the failure and aborts the canary. Traffic drains from the bad pods. Ten percent goes to zero. Canary pod scales down. Deleted.

**VOICEOVER:** Here's the critical detail. Look at the stable pod count. Still two. Still serving a hundred percent of traffic. At no point did `v1.1.2` own the majority. At no point did we cut over and then roll back. We stopped the promotion mid-flight.

**VOICEOVER:** This is not a rollback. This is a canary that never got promoted. The bad release never became "production." It served ten percent of traffic for eight minutes, failed its gate, and got killed. Your users? Ninety percent of them never saw it.

**VOICEOVER:** Pro tip number seven: canary deployments only work if you actually measure the canary and are willing to abort. This is that workflow. Guardian sets the bar. Argo enforces it. Humans sleep.

**SCREEN:** GitHub Actions log continues — a commit comment appears on the `v1.1.2` release commit with the Guardian evidence.

```
🚨 Release v1.1.2 blocked by Site Reliability Guardian

Canary aborted at 10% weight after 8 minutes.

Failing objectives:
  - frontend-p95-latency: 312ms (target: <200ms) — +56% regression
  - error-budget-burn: 3.1 (target: <1.0) — burning 3× too fast

AnalysisRun: https://argocd.example.com/rollouts/checkout/analysisrun-abc123
Guardian run: https://dynatrace.example.com/ui/guardians/runs/xyz789

Dashboards and SLOs are version-agnostic — no re-stamping needed.
Only the per-release Guardian (checkout-release-v1.1.2) was specific to this deploy.
```

**VOICEOVER:** And CI closes the loop. It posts a comment on the release commit. Objective that failed, by how much, links to the AnalysisRun and the Guardian evaluation. Everything you need to debug. Notice what we didn't have to do — re-stamp dashboards or SLOs. They're version-agnostic. The only per-release resource was the Guardian, and that's by design. One less thing to undo when a release fails.

**VOICEOVER:** Zero pages. Zero Slack alerts. Zero humans woken up. The pipeline detected the regression, stopped the rollout, and documented what happened. I'm asleep. My users are fine. That's the goal.

---

## 8:05–8:15 · THE BIGGER PICTURE

**ON-CAMERA:** Henrik on the sofa, direct to camera, ~10 seconds.

**VOICEOVER:** Step back for a second. What did we just build? Semantic conventions, dashboards, SLOs, and release gates — all YAML, all versioned with your git tag, all shipped together. Weaver catches breaking changes in PR. Claude fixes drift. Guardian blocks bad releases before they cut over. Agents do the work. Humans review the PR and sleep through the deploy. That's the goal.

---

## 8:15–8:35 · WRAP-UP & CALL TO ACTION

**TITLE CARD:** Repo URL + quickstart commands.

```
Repository: github.com/henrikrexed/observe-resolve-ep9-dtctl

Quickstart:
  make scenario-1    # Ship v1.1.0 the GitOps way
  make scenario-2    # Break it, let Claude fix drift
  make scenario-3    # Guardian blocks a bad canary

Your first dtctl command:
  dtctl auth login   # Connect to your tenant
  dtctl get dashboards | head -5
```

**VOICEOVER:** Everything you saw today is in the repo — link in the description. Clone it, run the three scenarios, see it work. Each scenario is a single `make` target. Takes five minutes to run all three. And if you want to try dtctl yourself, start with `dtctl auth login` and `dtctl get dashboards`. Feel what it's like to treat observability as code.

**TITLE CARD:** Subscribe animation. End screen with next-episode thumbnail and three "Pro Tips" badges from the episode. Brief ON-CAMERA of Henrik over the top.

**VOICEOVER:** Seven pro tips in eight minutes. Let me know in the comments which one you're adding to your workflow first. Subscribe if you want more content like this — we're doing one every two weeks. Next episode — wiring the Guardian verdict into a Slack approval flow for human-in-the-loop overrides. Thanks for watching. See you in the next one. Bye!

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
- SR-8 · Dynatrace dashboard with "Active Release" tile showing live version + version dropdown variable (Beat 1)
- SR-9 · v1.1.1 dashboard — customer-tier filter inert, errors-by-tier table empty, SLO tile `—`. Zoom-ins on each (Beat 2)
- SR-10 · GitHub Actions tab with `observability-watch` run (Beat 2)
- SR-11 · GitHub Issue #42 body — drift table + embedded Claude prompt (Beat 2)
- SR-12 · Claude Code terminal — tool calls + proposed diff, with the `checkout/main.py` snippet held readable (Beat 2)
- SR-13 · Same dashboard as SR-9, recovering — filter responsive, table populated, SLO measuring (Beat 2)
- SR-14 · Dynatrace Guardian UI — clock overlay 0:00 → 10:00 speed-ramped (Beat 3)
- SR-15 · Guardian verdict screen: `fail` with per-objective outcomes (Beat 3)
- SR-16 · Argo Rollouts UI — AnalysisRun `srg-verdict` → `Failed`, Rollout `Degraded`, traffic draining (Beat 3)
- SR-17 · GitHub Actions + release-commit comment with Guardian evidence (Beat 3)
- SR-18 · Dashboard "Active Release" tile showing live version after canary abort (Beat 3)

**Diagrams / schemas (build in post):**

- D-1 · `customer.tier` → `customerTier` code-diff overlay, anchored to a single broken dashboard tile (Pain)
- D-2 · Week-timeline animation — dashboard tiles decay one per day, support-ticket counter ticking up (Pain)
- D-3 · Three-box animation — code / conventions / dashboards stamped by a single `v1.1.0` tag (Solution)
- D-4 · Five numbered tiles slide (Weaver, dtctl, drift watcher, Argo CD+Rollouts, SRG) — each lighting up in turn (Solution)
- D-5 · 2×2 skill-stack grid — dtctl skill · Dynatrace-for-AI · observability-agent-skills · observability-repair (Solution)
- D-6 · dtctl command reference card — clean typography, six core commands with descriptions, screenshot-friendly (Command Cheat Sheet)
- D-7 · Architecture diagram — three layers (cluster, operators, app) with OTLP flow and "no OneAgent" callout (Demo Setup)
- D-8 · Split-screen code comparison — broken v1.1.1 vs Claude's fix with both attributes, highlights on each section (Beat 2)
- D-9 · Three-panel synchronized diff — registry, code, dashboard changes all visible at once (Beat 2)
- D-10 · Guardian verdict terminal output — styled CLI result with objective table and recommendation (Beat 3)

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
12. Dynatrace Site Reliability Guardian docs — docs.dynatrace.com

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

### Key Differences from v10 Draft (rollback of mesh + gateway)

The episode is about OpenTelemetry semantic-convention drift caught by Weaver — not about the service-mesh / ingress layer. v10 added Istio ambient + kgateway to fit a tighter cluster; v11 rolls those back because they're not part of the story.

1. **Istio ambient mesh removed.** No `istioctl install`, no ztunnel DaemonSet, no namespace ambient labeling.
2. **kgateway removed.** No Helm chart, no Gateway resource, no HTTPRoute. The corresponding manifests (`gateway.yaml`, `httproute-checkout.yaml`) are stub files marked DEPRECATED.
3. **Argo Rollouts reverted to scaling-based canary.** No `trafficRouting` block in the Rollout. The controller manages the canary by adjusting the canary replica count proportional to `setWeight` — at `setWeight: 10` and `replicas: 3` you get ~1 canary pod and 2 stable pods, kube-proxy round-robin gives you roughly the right traffic ratio. The AnalysisRun → Guardian verdict mechanic is unchanged on camera.
4. **`deploy/rollouts/plugin-config.yaml`** and **`rbac-gateway-api.yaml`** kept as DEPRECATED stubs — the Gateway API plugin is no longer wired in.
5. **`deploy.sh` shrank** from ten phases to five: cert-manager, Dynatrace Operator, OpenTelemetry Operator, Argo CD/Rollouts, app seed.
6. **Demo Setup VO** reverted: drops the ambient-mesh + kgateway sentence; just names the operators + Cilium CNI.
7. **Beat 3 VO** reverted: *"Ten percent of canary pods on v1.1.2, the rest still on v1.1.1"* — replica-based language instead of HTTPRoute weights.
8. **Description Box Links** trimmed — kgateway, Istio ambient, Cilium, and the Argo Rollouts Gateway API plugin are out.
9. **What's kept from v10:** the resource trims (ActiveGate 512 MiB, OTel Collector 1 replica, otel-demo lighter limits, Argo CD scaled-down components). The 2×8 GiB cluster still fits with comfortable headroom; the steady-state footprint is now lower because we dropped istiod (~512 MiB) and ztunnel (~256 MiB across 2 nodes) and kgateway (~128 MiB).

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
