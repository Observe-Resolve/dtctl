# Demo app — topology

The episode runs on a CAPI-provisioned cluster of **2 workers × 4 vCPU / 8 GiB**, Cilium CNI pre-installed. The stack is deliberately minimal — only the pieces the episode actually demonstrates. No service mesh, no Gateway API; the episode focus is OpenTelemetry semantic-convention drift caught by Weaver, not the network layer.

```
┌──────────────── your cluster (2×8GB, Cilium CNI) ────────────────┐
│                                                                  │
│  cert-manager        (webhook deps for the two operators)        │
│                                                                  │
│  dynatrace                                                       │
│    └─ DynaKube "demo"                                            │
│         kubernetesMonitoring: enabled                            │
│         activeGate: 1 replica (512 MiB) — k8s-monitoring + routing│
│         (no oneAgent → 100% OpenTelemetry for app telemetry)     │
│                                                                  │
│  opentelemetry-operator-system                                   │
│    ├─ OpenTelemetryCollector "gateway"  (1 replica, 512 MiB)     │
│    └─ Instrumentation "otel-demo-instrumentation"                │
│                                                                  │
│  argocd              (non-HA, dex + applicationset scaled to 0)  │
│    └─ Application "otel-demo-light" watching deploy/helm/values.yaml │
│                                                                  │
│  argo-rollouts                                                   │
│    ├─ controller (scaling-based canary, no traffic-router plugin)│
│    └─ AnalysisTemplate "srg-verdict" (polls dtctl get guardian-run)│
│                                                                  │
│  otel-demo                                                       │
│    ├─ Rollout "checkout" (3 replicas · canary 10 → 50 → 100      │
│    │                       with SRG analysis between each step)  │
│    └─ Deployments: frontend, cart, payment, product-catalog,     │
│                   recommendation, shipping, flagd, load-generator│
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ OTLP
                              ▼
              ┌────────────────────────────┐
              │      Dynatrace tenant      │
              │ Smartscape · DQL · Guardian │
              └────────────────────────────┘
```

## Resource footprint (approximate, steady state)

| Namespace / Component | CPU requests | Memory requests |
|---|---|---|
| cert-manager | 40m | 180 MiB |
| dynatrace (operator + ActiveGate) | 150m | 380 MiB |
| opentelemetry-operator-system | 100m | 256 MiB |
| otel-demo/gateway collector (1 replica) | 50m | 128 MiB |
| argocd (trimmed) | 300m | 700 MiB |
| argo-rollouts | 100m | 200 MiB |
| otel-demo (9 services + load gen, Rollout 3 replicas) | 620m | 1.1 GiB |
| **Subtotal — steady state** | **~1.4 vCPU** | **~3.0 GiB** |
| Canary burst (+3 checkout replicas during Beat 3) | +300m | +384 MiB |
| System overhead (kubelet, CoreDNS, metrics-server, Cilium agents, CSI nodes) | ~800m | ~1.5 GiB |
| **Peak total** | **~2.5 vCPU** | **~4.9 GiB** |

Cluster allocatable on 2×8 GiB workers is ~12 GiB / ~7 vCPU, so this fits with ~3 GiB of memory headroom and ~4 vCPU idle at peak.

## Bootstrap

```bash
./demo-app/deploy.sh \
    --clustername       my-cluster \
    --dturl             https://abc12345.live.dynatrace.com \
    --dtoperatortoken   dt0c01.OPERATOR_TOKEN... \
    --dtingesttoken     dt0c01.INGEST_TOKEN...
```

The script does the following, in order:

1. **Pre-flight check** — verifies `jq`, `git`, `helm`, `kubectl` are on `PATH`; validates required args.
2. **cert-manager** — `kubectl apply -f https://github.com/cert-manager/.../cert-manager.yaml`, then waits for the webhook pod.
3. **OpenTelemetry Operator** — `kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/...`, waits for Ready.
4. **Dynatrace Operator** — `helm upgrade dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator --version 1.9.0 --namespace dynatrace --create-namespace --install --atomic`. Then creates the `dynakube` token secret and `sed`-substitutes `TENANTURL_TOREPLACE` + `CLUSTER_NAME_TO_REPLACE` into the DynaKube YAML.
5. **OTel Collector gateway + Instrumentation CR** — creates the `otel-demo` namespace, labels it `oneagent=false`, creates the `dynatrace` secret with `dynatrace_oltp_url` + `dt_api_token` + `clustername`, sed-substitutes the cluster name into the manifests, applies them.
6. **Argo CD** — non-HA install, dex + applicationset scaled to 0.
7. **Argo Rollouts + SRG AnalysisTemplate** — applies the controller, then `srg-verdict` AnalysisTemplate.
8. **otel-demo-light** — `helm upgrade --install otel-demo open-telemetry/opentelemetry-demo --values demo-app/values.yaml`.
9. **DynaKube** — `kubectl apply -f demo-app/manifests/dynakube.yaml`, waits for Ready.
10. **Argo CD Application** — `kubectl apply -f deploy/argocd/application.yaml`, then seeds `deploy/helm/values.yaml` with `tag: v1.0.0` — Argo CD reconciles from here.

Token scopes:

- `--dtoperatortoken` — `entities.read`, `settings.read`, `settings.write`, `activeGateTokenManagement.create`
- `--dtingesttoken`   — `metrics.ingest`, `logs.ingest`, `events.ingest`, `openTelemetryTrace.ingest`

> **macOS vs Linux note:** the script uses `sed -i ''` (BSD sed). On Linux drop the empty `''` argument or replace with `sed -i`.

## Who owns what after bootstrap

| Layer | Owner | Where the spec lives |
|---|---|---|
| Checkout image tag (the bump) | **GitHub Actions** (`release.yml`) | rewrites `deploy/helm/values.yaml` on every git tag |
| Rollout + canary progression + AnalysisTemplate | **Argo CD** + **Argo Rollouts** | `deploy/helm/templates/` (Helm chart Argo CD reconciles) |
| Canary traffic split | **Argo Rollouts** (scaling-based — no mesh, no Gateway API) | replica count via `setWeight` |
| K8s entity discovery | **Dynatrace Operator** | `demo-app/manifests/dynakube.yaml` |
| OTLP collection | **OpenTelemetry Operator** | collector manifests in `demo-app/manifests/` |
| Dashboards / SLOs / Guardian | **GitHub Actions** via `dtctl apply` | `dtctl/**/*.yaml` |

Nothing in the hot path applies resources by hand. Every deployable artifact is version-controlled and reconciled.

## End-to-end release loop (the on-camera Beat 1 / Beat 3 flow)

```
   developer pushes git tag vX.Y.Z
            │
            ▼
   ┌────────────────────────────────────────────────┐
   │ .github/workflows/release.yml                  │
   │  1. build-checkout  → ghcr.io/.../checkout:vX.Y.Z │
   │  2. apply-dtctl     → dtctl apply (dashboards, SLOs, Guardian) │
   │  3. promote-via-argo→ sed-bump deploy/helm/values.yaml +     │
   │                       git push                                │
   └────────────────────────────────────────────────┘
            │
            ▼
   Argo CD detects values.yaml change → reconciles `deploy/helm/`
            │
            ▼
   Argo Rollouts sees new podSpec hash → starts canary
            │
            ├─► 10% pods on vX.Y.Z, 2-min soak, AnalysisRun (`srg-verdict`)
            │       └── Job → `dtctl get guardian-run` → pass/warn/fail
            │
            ├─► 50% pods on vX.Y.Z, 2-min soak, AnalysisRun (`srg-verdict`)
            │
            └─► 100% on vX.Y.Z (success) │ OR │ abort (Guardian fail)
                                                └── on-failure job in CI
                                                    re-stamps dtctl to previous tag
                                                    + posts evidence on the release commit
```

The whole loop is reproducible — one tag push triggers the entire chain. CI never runs `helm upgrade` directly.

## Environment

```bash
DT_API_URL=https://ENV-ID.live.dynatrace.com/api
DT_OTLP_ENDPOINT=https://ENV-ID.live.dynatrace.com/api/v2/otlp
DT_API_TOKEN=dt0c01.XXXX...             # entities.read, settings.read/write, activeGateTokenManagement.create
DT_DATA_INGEST_TOKEN=dt0c01.XXXX...     # metrics.ingest, logs.ingest, events.ingest, openTelemetryTrace.ingest
```

## What we changed vs upstream otel-demo-light

1. **Chart's built-in collector disabled** — the OpenTelemetry Operator's `gateway` collector is the single OTLP egress.
2. **Chart's `checkout` component disabled.** We ship our own checkout service — see [`demo-app/services/checkout/`](services/checkout/README.md). Vendored Python FastAPI, ~80 lines, easy to edit on camera. The Argo Rollout in `deploy/rollouts/rollout.yaml` runs *our* image (`ghcr.io/henrikrexed/checkout:$TAG`), not the chart's.
3. **Every service points `OTEL_EXPORTER_OTLP_ENDPOINT`** at the operator-managed gateway collector.
4. **`customer.tier` and `payment.method` span attributes** in `checkout.place_order` — used by the dashboard tile and the drift scenario in Beat 2. (See `demo-app/services/checkout/main.py`.)
5. **Three patch scripts** under `services/checkout/patches/` that the scenario runners call to apply Beat 1 / Beat 2 / Beat 3 code changes deterministically.
6. **All resource limits trimmed** to fit 2×8 GiB (see table above).

## Files retained as DEPRECATED stubs

These were part of an earlier draft that layered Istio ambient + kgateway. They're harmless empty stubs now and safe to delete from your fork:

- `demo-app/manifests/gateway.yaml`
- `demo-app/manifests/httproute-checkout.yaml`
- `deploy/rollouts/plugin-config.yaml`
- `deploy/rollouts/rbac-gateway-api.yaml`
