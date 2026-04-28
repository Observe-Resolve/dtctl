# Deployment runbook

End-to-end checklist from "I have a 2 × 8 GB CAPI cluster" to "the first scenario runs cleanly." Roughly **45 minutes**, most of it waiting for operators to come up.

---

## 0. Prerequisites — install once on your laptop

| Tool | Version | Install |
|---|---|---|
| `kubectl` | 1.32+ | https://kubernetes.io/docs/tasks/tools/ |
| `helm` | 3.14+ | https://helm.sh/docs/intro/install/ |
| `jq` | any | `brew install jq` |
| `git` | any | already there |
| `gh` (GitHub CLI) | latest | `brew install gh` — needed by the scenario runners |
| `dtctl` | latest | https://github.com/dynatrace-oss/dtctl/releases |
| Claude Code | latest | https://docs.claude.com/en/docs/claude-code |
| `weaver` | 0.17+ | https://github.com/open-telemetry/weaver/releases |
| `kubectl-argo-rollouts` | latest | `kubectl krew install argo-rollouts` (recommended for the on-camera Argo Rollouts UI) |

Verify everything resolves:

```bash
for c in kubectl helm jq git gh dtctl weaver; do command -v "$c" || echo "missing: $c"; done
```

---

## 1. Dynatrace tenant prep

Two API tokens with non-overlapping scopes. Create them in **Dynatrace → Access tokens → Generate new token**:

| Token | Used by | Scopes |
|---|---|---|
| **Operator token** (`--dtoperatortoken`) | Dynatrace Operator's DynaKube CR | `entities.read`, `settings.read`, `settings.write`, `activeGateTokenManagement.create` |
| **Ingest token** (`--dtingesttoken`) | OTel Collector OTLP exporter + DynaKube data ingest | `metrics.ingest`, `logs.ingest`, `events.ingest`, `openTelemetryTrace.ingest` |

Sanity test — replace `$DT_URL` and `$DT_OPERATOR_TOKEN`:

```bash
curl -sH "Authorization: Api-Token $DT_OPERATOR_TOKEN" "$DT_URL/api/v2/entities?pageSize=1" | jq .totalCount
# expect a number, not an auth error
```

For the GitHub Actions release pipeline (`release.yml`) you also need an **OAuth client** (separate from the API tokens). Create it in **Dynatrace → Settings → Integration → Dynatrace tokens → OAuth clients**, with the following scopes:

**Required OAuth scopes:**
* All dtctl preset scopes (easiest: select "dtctl" preset, then add the additional scopes below)
* `storage:events:write` — **CRITICAL** for sending SDLC deployment events that trigger Site Reliability Guardian validation runs
* `app-engine:apps:run` — for executing Dynatrace workflows
* `document:documents:write` — for dashboards and notebooks
* `automation:workflows:write` — for workflow definitions
* `slo:slo:write` — for SLO definitions
* `settings:objects:write` — for guardian definitions

**Why `storage:events:write` is required:**

The Site Reliability Guardian configured in `dtctl/guardians/checkout-release-guardian.yaml` has `eventKind: "SDLC_EVENT"`, which means it requires an SDLC deployment event to trigger each validation run. Without this scope, the release pipeline cannot send the event, and the guardian will never evaluate — causing the Argo Rollouts AnalysisTemplate to timeout waiting for a verdict.

The `.github/workflows/release.yml` pipeline sends this event in the "Trigger Guardian validation" step (after applying dtctl resources) via a direct call to the Dynatrace Events API v2 (`/api/v2/events/ingest`).

Save the client-id and client-secret somewhere safe — you'll need them for both local `dtctl auth login` and GitHub Actions secrets.

---

## 2. Cluster prep

You already provisioned a 2 × 8 GB CAPI cluster with Cilium. Verify it's healthy:

```bash
kubectl get nodes -o wide
kubectl -n kube-system get daemonset cilium
kubectl -n kube-system rollout status daemonset cilium --timeout=2m
```

Verify there's a default StorageClass (Argo CD needs one for redis state):

```bash
kubectl get storageclass | grep '(default)' || echo "::warning:: no default StorageClass"
```

If you're not on a cloud provider that auto-provisions one, install local-path-provisioner:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true
```

---

## 3. Clone the repo + bootstrap

```bash
git clone https://github.com/henrikrexed/observe-resolve-ep9-dtctl
cd observe-resolve-ep9-dtctl

./demo-app/deploy.sh \
    --clustername       ep9-demo \
    --dturl             https://abc12345.live.dynatrace.com \
    --dtoperatortoken   dt0c01.OPERATOR_TOKEN... \
    --dtingesttoken     dt0c01.INGEST_TOKEN...
```

This takes ~10 minutes. The script prints the Argo CD URL and password recovery one-liner at the end. Open that UI in a browser — you should see the `otel-demo-light` Application syncing.

---

## 4. Verify the cluster looks right

```bash
# All namespaces present
kubectl get ns | grep -E 'cert-manager|opentelemetry|dynatrace|argocd|argo-rollouts|otel-demo'

# All operator pods Ready
kubectl -n cert-manager                       wait pod --for=condition=Ready --all --timeout=2m
kubectl -n opentelemetry-operator-system      wait pod --for=condition=Ready --all --timeout=2m
kubectl -n dynatrace                          wait pod --for=condition=Ready --all --timeout=5m
kubectl -n argocd                             wait pod --for=condition=Ready --all --timeout=5m
kubectl -n argo-rollouts                      wait pod --for=condition=Ready --all --timeout=2m

# OTel demo app pods up
kubectl -n otel-demo get pods

# Argo CD application synced
kubectl -n argocd get application otel-demo-light -o jsonpath='{.status.sync.status} / {.status.health.status}'
# expect: Synced / Healthy

# checkout Rollout healthy at v1.0.0
kubectl-argo-rollouts -n otel-demo get rollout checkout
# expect phase: Healthy, image: ghcr.io/.../checkout:v1.0.0
```

Open Dynatrace, navigate to **Smartscape Services** — you should see `frontend`, `cart`, `checkout`, `payment`, `product-catalog`, `recommendation`, `shipping`, `flagd`, and the load generator.

---

## 5. Auth dtctl + apply the baseline observability resources

```bash
dtctl auth login \
    --oauth-client-id     dt0s02.YOUR_CLIENT_ID \
    --oauth-client-secret dt0s02.YOUR_CLIENT_SECRET \
    --env                 https://abc12345.live.dynatrace.com
dtctl auth verify
```

Apply the baseline `dtctl/` manifests at `v1.0.0`:

```bash
make baseline
```

This stamps `APP_VERSION=v1.0.0` into every dashboard / SLO / workflow YAML and applies them to your tenant. After this, your Dynatrace tenant has the dashboards and SLOs the episode demonstrates.

### Understanding the Site Reliability Guardian flow

The guardian defined in `dtctl/guardians/checkout-release-guardian.yaml` has `eventKind: "SDLC_EVENT"`, which means:

1. **The guardian definition is passive** — it just sits in Dynatrace waiting for events
2. **An SDLC event must be sent** to trigger a validation run for a specific release
3. **The GitHub Actions release workflow sends this event** after applying dtctl resources

**The complete flow:**

```
GitHub tag v1.2.3 pushed
  ↓
release.yml runs:
  1. Build + push checkout:v1.2.3 image
  2. dtctl apply -f dtctl/ (including guardian definition)
  3. Send SDLC deployment event via Events API v2  ← triggers guardian evaluation
  4. Bump deploy/helm/values.yaml image.tag → git push
  ↓
Argo CD reconciles → new Rollout revision created
  ↓
Argo Rollouts starts canary (10% → 50% → 100%)
  ↓
AnalysisTemplate polls: dtctl get guardian-run --guardian checkout-release-v1.2.3 --latest
  ↓
Guardian verdict: pass → promote | fail → abort
```

**Why the Dynatrace workflow exists:**

The file `dtctl/workflows/guardian-validation.yaml` is an **alternative trigger mechanism** that listens for Kubernetes deployment events. It's not used in the current GitHub Actions flow (which sends the SDLC event directly), but it's there for environments where:
- You want Dynatrace to react to K8s deployments automatically (requires Dynatrace Kubernetes monitoring to generate K8S_DEPLOYMENT events)
- You deploy via kubectl/Helm directly instead of through CI/CD

For this episode, the **direct Events API call from GitHub Actions** (release.yml:122-145) is the primary trigger.

---

## 6. GitHub Actions secrets (for the on-camera release flow)

Set these as **repo secrets** in `Settings → Secrets and variables → Actions`:

| Secret | Value | Used by |
|---|---|---|
| `DT_OAUTH_CLIENT_ID` | from step 1 | `release.yml` |
| `DT_OAUTH_CLIENT_SECRET` | from step 1 | `release.yml` |
| `DT_ENVIRONMENT` | your tenant URL (e.g. `https://abc12345.live.dynatrace.com`) | `release.yml` |
| `GITHUB_TOKEN` | auto-provided | `release.yml` to push the values bump |

CI doesn't talk to your cluster — the release pipeline is three jobs only (build → apply-dtctl → promote-via-argo). After the values bump, Argo CD reconciles inside the cluster and Argo Rollouts owns the canary. You watch the result in the Argo Rollouts UI on your laptop.

If a release fails (Guardian aborts the canary), roll dtctl back manually:

```bash
make rollback TAG=v1.1.1   # whatever was the previous good version
```

That re-stamps every dashboard / SLO / Guardian to match the version actually serving traffic. The `Makefile` target is one line; nothing in CI needs cluster access.

---

## 7. Smoke test — run scenario-1 end to end (off camera)

Don't do this on camera the first time. It's the dress rehearsal.

```bash
make scenario-1
```

What you should see:

1. New branch `feat/cart-size-attribute` created
2. `add-cart-size.sh` patches `demo-app/services/checkout/main.py`
3. PR opens, all CI checks go green (Weaver + dtctl validate + Helm lint + checkout build + tests)
4. PR merges, `git tag v1.1.0` pushed
5. `release.yml` runs — image push, `dtctl apply`, `values.yaml` bump
6. Argo CD UI flips to OutOfSync → Synced
7. Argo Rollouts UI walks the canary 10 → 50 → 100 with green AnalysisRuns
8. Dynatrace dashboard gets the new "Cart size distribution" tile, version badge `v1.1.0`

If any step fails, fix it before recording.

---

## 8. (For the recording) Reset the tenant between takes

If you want a clean slate after a take:

```bash
# Delete the dtctl resources for this episode
dtctl delete dashboards --selector episode=09 --yes
dtctl delete slos       --selector episode=09 --yes
dtctl delete workflows  --selector episode=09 --yes
dtctl delete guardians  --selector episode=09 --yes

# Re-stamp at the baseline
make baseline
```

---

## 9. Common gotchas

| Symptom | Likely cause | Fix |
|---|---|---|
| `applicationsets.argoproj.io` CRD apply fails with `metadata.annotations: Too long: may not be more than 262144 bytes` | Client-side `kubectl apply` adds a `last-applied-configuration` annotation that pushes the CRD past the 256KB metadata limit | The bootstrap script uses `kubectl apply --server-side=true --force-conflicts` for both Argo CD and Argo Rollouts. If you're applying manually, add those flags. (See [Argo CD docs — Server-Side Apply](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)) |
| `Error: values don't meet the specifications of the schema(s) … Additional property components is not allowed` | `components`, `serviceAccount`, or subchart toggles got nested under `default:` in `demo-app/values.yaml` | The chart's JSON schema requires those at the **root** of the values file. `default:` only accepts the chart's own keys (`envOverrides`, `image`, etc.). Fixed in the latest `values.yaml`. |
| `dynakube` pod stuck in `Init` | Token secret missing or wrong scopes | `kubectl -n dynatrace describe pod` and check token scopes in Dynatrace UI |
| `OpenTelemetryCollector` reports webhook timeout | `cert-manager` webhook not Ready before OTel Operator starts | Re-run `deploy.sh` — the script's `sleep 10` after cert-manager is usually enough |
| Argo CD UI 503 | `argocd-server` pod restarting under memory pressure | `kubectl -n argocd top pod` — if the cluster is memory-tight, scale `argocd-repo-server` to 1 replica |
| Rollout stuck at canary 10% | Guardian returns `inconclusive` (`warn`) instead of `pass` | Default behavior: AnalysisTemplate treats `warn` as inconclusive (does not promote, does not abort). Promote manually with `kubectl-argo-rollouts -n otel-demo promote checkout` if you want to continue |
| AnalysisTemplate times out waiting for guardian verdict | No guardian run started (no SDLC event received) | OAuth client is missing `storage:events:write` scope, or the "Trigger Guardian validation" step in `release.yml` failed. Check GitHub Actions logs for the SDLC event send step. Manually verify: `dtctl get guardian-run --guardian checkout-release-v1.x.x --latest` — if empty, no event was received |
| Guardian verdict is `fail` but you want to promote anyway | Guardian objectives genuinely failed (check SLO thresholds in `dtctl/guardians/*.yaml`) | This is the guardian working as designed. If you want to override and promote: `kubectl-argo-rollouts -n otel-demo promote checkout`. To bypass guardians for testing, comment out the `analysis:` block in `deploy/helm/templates/rollout.yaml` |
| `dtctl apply` says `unknown apiVersion` | `dtctl` binary older than the manifests | Update `dtctl` — `make baseline` and CI both expect a recent build |
| GitHub Actions `release.yml` `promote-via-argo` fails to push | `GITHUB_TOKEN` lacks `contents: write` | Workflow already declares `permissions: contents: write` — verify your repo settings allow Actions to write |
| Events API returns 401 during "Trigger Guardian validation" step | OAuth token request failed or scope is missing | Verify `DT_OAUTH_CLIENT_ID`, `DT_OAUTH_CLIENT_SECRET`, and `DT_ENVIRONMENT` secrets are set correctly in GitHub. OAuth client must have `storage:events:write` scope |
