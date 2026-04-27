#!/usr/bin/env bash
# Inject latency + errors into the checkout service to fire the SLO breach alert.
# Used in Ep. 09 Act 3 (~6:00).
#
# Usage:
#   ./chaos/break-checkout.sh           # inject for 90s
#   ./chaos/break-checkout.sh --recover # cancel injection immediately
set -euo pipefail

NAMESPACE="${NAMESPACE:-otel-demo}"
DEPLOYMENT="${DEPLOYMENT:-checkout}"
DURATION_SEC="${DURATION_SEC:-90}"
LATENCY_MS="${LATENCY_MS:-500}"
ERROR_PCT="${ERROR_PCT:-30}"

log() { printf "\033[1;33m[chaos]\033[0m %s\n" "$*"; }

inject() {
  log "Injecting ${LATENCY_MS}ms latency + ${ERROR_PCT}% error rate into ${DEPLOYMENT}..."
  kubectl -n "$NAMESPACE" set env deployment/"$DEPLOYMENT" \
      CHAOS_LATENCY_MS="$LATENCY_MS" \
      CHAOS_ERROR_PCT="$ERROR_PCT"
  kubectl -n "$NAMESPACE" rollout status deployment/"$DEPLOYMENT" --timeout=60s

  log "Fault active. Will run for ${DURATION_SEC}s (Ctrl-C to abort early)."
  trap recover INT TERM
  sleep "$DURATION_SEC"
  recover
}

recover() {
  log "Recovering ${DEPLOYMENT}..."
  kubectl -n "$NAMESPACE" set env deployment/"$DEPLOYMENT" \
      CHAOS_LATENCY_MS- CHAOS_ERROR_PCT-
  kubectl -n "$NAMESPACE" rollout status deployment/"$DEPLOYMENT" --timeout=60s
  log "Done. SLO should climb back to green within ~2-3 minutes."
}

case "${1:-inject}" in
  --recover) recover ;;
  inject|"") inject ;;
  *)         echo "Unknown arg: $1"; exit 1 ;;
esac
