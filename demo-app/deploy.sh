#!/usr/bin/env bash

################################################################################
### Script deploying the Observe & Resolve Episode 9 environment
### (Dashboards Are Part of Your API — dtctl + Weaver + Site Reliability Guardian)
###
### Parameters:
### --clustername       : name of your k8s cluster
### --dturl             : URL of your Dynatrace tenant, no trailing slash
###                       e.g. https://abc12345.live.dynatrace.com
### --dtoperatortoken   : API token for the Dynatrace Operator
###                       Scopes: entities.read, settings.read, settings.write,
###                               activeGateTokenManagement.create
### --dtingesttoken     : Data ingest token for OTLP + DynaKube data ingest
###                       Scopes: metrics.ingest, logs.ingest, events.ingest,
###                               openTelemetryTrace.ingest
###
### What it deploys (in order):
###   1. cert-manager
###   2. OpenTelemetry Operator
###   3. Dynatrace Operator + DynaKube (K8s monitoring only — no OneAgent)
###   4. OTel Collector gateway + Instrumentation CR
###   5. Argo CD (trimmed: dex + applicationset scaled to 0)
###   6. Argo Rollouts + SRG AnalysisTemplate
###   7. otel-demo-light (the app being measured)
###   8. Argo CD Application pointing at deploy/helm/values.yaml
################################################################################


### Pre-flight checks for dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo "Please install jq before continuing"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Please install git before continuing"
    exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
    echo "Please install helm before continuing"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "Please install kubectl before continuing"
    exit 1
fi

echo "parsing arguments"
while [ $# -gt 0 ]; do
  case "$1" in
   --dtoperatortoken)
          DTOPERATORTOKEN="$2"
         shift 2
          ;;
       --dtingesttoken)
          DTTOKEN="$2"
         shift 2
          ;;
       --dturl)
          DTURL="$2"
         shift 2
          ;;
       --clustername)
         CLUSTERNAME="$2"
         shift 2
         ;;

  *)
    echo "Warning: skipping unsupported option: $1"
    shift
    ;;
  esac
done

echo "Checking arguments"
 if [ -z "$CLUSTERNAME" ]; then
   echo "Error: clustername not set!"
   exit 1
 fi
 if [ -z "$DTURL" ]; then
   echo "Error: Dt url not set!"
   exit 1
 fi

 if [ -z "$DTTOKEN" ]; then
   echo "Error: Data ingest api-token not set!"
   exit 1
 fi

 if [ -z "$DTOPERATORTOKEN" ]; then
   echo "Error: DT operator token not set!"
   exit 1
 fi


#### Deploy the cert-manager
echo "Deploying Cert Manager ( for OpenTelemetry Operator)"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
# Wait for pod webhook started
kubectl wait pod -l app.kubernetes.io/component=webhook -n cert-manager --for=condition=Ready --timeout=2m
sleep 10

#### Deploy the OpenTelemetry Operator
echo "Deploying the OpenTelemetry Operator"
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
kubectl wait pod -l app.kubernetes.io/name=opentelemetry-operator -n opentelemetry-operator-system --for=condition=Ready --timeout=2m


#### Deploy the Dynatrace Operator (K8s monitoring only — no OneAgent)
echo "Deploying the Dynatrace Operator"
helm upgrade dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --version 1.9.0 \
  --create-namespace --namespace dynatrace \
  --install \
  --atomic
kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s

kubectl -n dynatrace create secret generic dynakube --from-literal="apiToken=$DTOPERATORTOKEN" --from-literal="dataIngestToken=$DTTOKEN"
sed -i '' "s,TENANTURL_TOREPLACE,$DTURL,"          demo-app/manifests/dynakube.yaml
sed -i '' "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME," demo-app/manifests/dynakube.yaml


#### Deploy the OTel Collector gateway + Instrumentation CR
echo "Deploying the OpenTelemetry Collector gateway + Instrumentation CR"

kubectl  create secret generic dynatrace \
    --from-literal=dynatrace_oltp_url="$DTURL/api/v2/otlp" \
    --from-literal=dt_api_token="$DTTOKEN" \
    --from-literal=clustername="$CLUSTERNAME"

# Replace placeholders in collector + instrumentation manifests
find demo-app/manifests/ -name "openTelemetry-manifest_statefulset.yaml"  -exec sed -i '' "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME," {} +
find demo-app/manifests/ -name "openTelemetry-manifest_ds.yaml" -exec sed -i '' "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME," {} +

kubectl apply -f demo-app/manifests/rbac.yaml
kubectl apply -f demo-app/manifests/openTelemetry-manifest_ds.yaml
kubectl apply -f demo-app/manifests/openTelemetry-manifest_statefulset.yaml


#### Deploy Argo CD (trimmed: dex + applicationset scaled to 0)
echo "Deploying Argo CD"
kubectl create namespace argocd
# Server-side apply is REQUIRED here — the applicationsets.argoproj.io CRD
# exceeds the 256KB metadata limit when client-side apply auto-adds the
# kubectl.kubernetes.io/last-applied-configuration annotation.
# (See https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
kubectl -n argocd apply --server-side=true --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd scale deployment/argocd-dex-server --replicas=0
kubectl -n argocd scale deployment/argocd-applicationset-controller --replicas=0
kubectl -n argocd wait pod --for=condition=ready --selector=app.kubernetes.io/name=argocd-server --timeout=5m


#### Deploy Argo Rollouts + SRG AnalysisTemplate
echo "Deploying Argo Rollouts"
kubectl create namespace argo-rollouts
# Server-side apply for the same reason — Rollouts CRDs are large too.
kubectl -n argo-rollouts apply --server-side=true --force-conflicts \
    -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl -n argo-rollouts wait pod --for=condition=ready --selector=app.kubernetes.io/name=argo-rollouts --timeout=5m

# AnalysisTemplate that polls dtctl get guardian-run for the SRG verdict
find deploy/rollouts/ -name "analysistemplate-srg.yaml" -exec sed -i '' "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME," {} +
kubectl apply -f deploy/rollouts/analysistemplate-srg.yaml

# Notification config — creates a GitHub issue when a canary is aborted.
# Requires `gh` CLI to be authenticated (`gh auth status`).
echo "Configuring Argo Rollouts notifications (GitHub issue on canary abort)"
GITHUB_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [ -n "$GITHUB_REPO" ]; then
  GITHUB_TOKEN=$(gh auth token)
  kubectl -n argo-rollouts create secret generic argo-rollouts-notification-secret \
    --from-literal=github-token="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  sed "s,GITHUB_REPO_TO_REPLACE,$GITHUB_REPO," deploy/notifications/configmap.yaml \
    | kubectl apply -f -
  echo "  Notifications configured for repo: $GITHUB_REPO"
else
  echo "  Warning: gh CLI not authenticated — skipping notification setup."
  echo "  Run 'gh auth login' and re-run to enable GitHub issue creation on canary abort."
fi


#### Deploy otel-demo-light (the app being measured)
echo "Deploying otel-demo-light"
kubectl create namespace otel-demo
kubectl label namespace otel-demo oneagent=false
kubectl create serviceaccount opentelemetry-demo -n otel-demo
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-demo open-telemetry/opentelemetry-demo \
    --namespace otel-demo \
    --values demo-app/values.yaml \
    --atomic --timeout 10m


#### Deploy the DynaKube
echo "Deploying the DynaKube (K8s monitoring only, no OneAgent injection)"
kubectl apply -f demo-app/manifests/dynakube.yaml -n dynatrace


#### Register the Argo CD Application + seed deploy/helm/values.yaml
echo "Registering the Argo CD Application"
sed -i '' "s,CLUSTER_NAME_TO_REPLACE,$CLUSTERNAME," deploy/argocd/application.yaml
kubectl apply -f deploy/argocd/application.yaml

echo "Seeding deploy/helm/values.yaml at 1.0.2 (Argo CD reconciles from here)"
sed -i '' "s,^  tag:.*,  tag: 1.0.2," deploy/helm/values.yaml

echo ""
echo "================================================================================"
echo "Bootstrap complete."
echo ""
echo "  Argo CD UI:        kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "  Argo CD password:  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "                       -o jsonpath='{.data.password}' | base64 -d ; echo"
echo "  Application:       kubectl -n argocd get application otel-demo-light -w"
echo "  Dynatrace UI:      $DTURL/ui/apps/dynatrace.services"
echo "================================================================================"
