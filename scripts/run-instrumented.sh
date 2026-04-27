#!/usr/bin/env bash
# run-instrumented.sh — wrap any `claude code` invocation in an OpenTelemetry span.
#
# Usage:
#   ./scripts/run-instrumented.sh \
#       --task agent.repair_drift_ticket \
#       --ticket 42 \
#       -- \
#       claude code --skill skills/observability-repair \
#                   --prompt "$(cat prompts/resolve-drift-ticket.md)"
#
# Behavior:
#   1. Generates W3C traceparent + resource attributes.
#   2. Emits a start log. Runs the command. Emits a finish log.
#   3. Both logs + the resulting span are exported to Dynatrace via OTLP.
#   4. Exit code propagates.
#
# Requirements:
#   - otel-cli (https://github.com/equinix-labs/otel-cli) on PATH
#   - OTEL_EXPORTER_OTLP_ENDPOINT + OTEL_EXPORTER_OTLP_HEADERS env vars set
#     (deploy.sh writes these into .env already)
set -euo pipefail

TASK="agent.generic_run"
TICKET=""
OUTCOME_HINT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)        TASK="$2"; shift 2 ;;
    --ticket)      TICKET="$2"; shift 2 ;;
    --outcome)     OUTCOME_HINT="$2"; shift 2 ;;
    --)            shift; break ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

: "${OTEL_EXPORTER_OTLP_ENDPOINT:?OTEL_EXPORTER_OTLP_ENDPOINT must be set}"
: "${OTEL_EXPORTER_OTLP_HEADERS:?OTEL_EXPORTER_OTLP_HEADERS must be set}"

REPO_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
SESSION_ID="${CLAUDE_SESSION_ID:-sess-$(date +%s)-$$}"
APP_VERSION="${APP_VERSION:-dev}"

export OTEL_SERVICE_NAME="claude-code-agent"
export OTEL_RESOURCE_ATTRIBUTES="service.name=claude-code-agent,\
agent.repo=observe-resolve-ep9-dtctl,\
agent.model=${CLAUDE_MODEL:-claude-sonnet-4.6},\
agent.session=${SESSION_ID},\
agent.repo_sha=${REPO_SHA},\
app.version=${APP_VERSION}"

if [[ -z "${OTEL_TRACES_EXPORTER:-}" ]]; then
  export OTEL_TRACES_EXPORTER="otlp"
fi

log() { printf '\033[1;36m[agent-obs]\033[0m %s\n' "$*" >&2; }

log "task=$TASK ticket=${TICKET:-none} session=$SESSION_ID"

START_TS="$(date +%s%N)"

# Emit a start log line so the session shows up even if the span export fails.
otel-cli log --severity info \
  --body "agent run started: $TASK" \
  --attr "agent.task=$TASK" \
  --attr "ticket.id=$TICKET" \
  --attr "agent.session=$SESSION_ID"

# Run the wrapped command inside a span. otel-cli span exec handles context
# injection into TRACEPARENT so child spans emitted by claude (via the
# agent-observability skill's helpers) attach correctly.
set +e
otel-cli span exec \
  --name "$TASK" \
  --attr "ticket.id=$TICKET" \
  --attr "agent.session=$SESSION_ID" \
  --attr "skill.names=observability-repair,dtctl,agent-observability" \
  --attr "app.version=$APP_VERSION" \
  -- "$@"
EXIT_CODE=$?
set -e

END_TS="$(date +%s%N)"
DURATION_MS=$(( (END_TS - START_TS) / 1000000 ))

if [[ $EXIT_CODE -eq 0 ]]; then
  OUTCOME="${OUTCOME_HINT:-completed}"
  STATUS="info"
else
  OUTCOME="error"
  STATUS="error"
fi

otel-cli log --severity "$STATUS" \
  --body "agent run finished: $TASK ($OUTCOME in ${DURATION_MS}ms)" \
  --attr "agent.task=$TASK" \
  --attr "ticket.id=$TICKET" \
  --attr "agent.session=$SESSION_ID" \
  --attr "outcome=$OUTCOME" \
  --attr "duration_ms=$DURATION_MS" \
  --attr "exit_code=$EXIT_CODE"

log "outcome=$OUTCOME duration=${DURATION_MS}ms exit=$EXIT_CODE"
exit "$EXIT_CODE"
