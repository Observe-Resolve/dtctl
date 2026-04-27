#!/usr/bin/env bash
# Poll a Site Reliability Guardian until it returns a terminal verdict.
# Emits JSON to stdout: { verdict, objectives: [...], durationSec }
#
# Usage:
#   scripts/run-guardian.sh <guardian-name> <timeout-seconds>
set -euo pipefail

NAME="${1:?guardian name required}"
TIMEOUT="${2:-720}"   # default 12 minutes
INTERVAL=30
ELAPSED=0

log() { printf '\033[1;36m[guardian]\033[0m %s\n' "$*" >&2; }

log "watching guardian '$NAME' (timeout=${TIMEOUT}s, interval=${INTERVAL}s)"

while (( ELAPSED < TIMEOUT )); do
  RESULT=$(dtctl get guardian-run --guardian "$NAME" --latest --output=json)
  STATUS=$(echo "$RESULT" | jq -r '.status')

  case "$STATUS" in
    running|pending)
      OBJS=$(echo "$RESULT" | jq -c '.objectives | map({name, value, pass})')
      log "t=${ELAPSED}s status=$STATUS objectives=$OBJS"
      sleep "$INTERVAL"
      ELAPSED=$((ELAPSED + INTERVAL))
      ;;
    pass|warn|fail)
      log "terminal verdict: $STATUS"
      echo "$RESULT" | jq --arg s "$STATUS" '. + {verdict: $s}'
      exit 0
      ;;
    *)
      log "unexpected status: $STATUS — aborting"
      echo "$RESULT" >&2
      exit 2
      ;;
  esac
done

log "timeout waiting for verdict"
echo "$RESULT" | jq '. + {verdict: "timeout"}'
exit 3
