#!/usr/bin/env bash
# SCENARIO 2 — Copilot detects observability drift, Claude resolves the ticket.
#
# Flow on camera:
#   1. Branch refactor/camelcase-attrs renames `customer.tier` -> `customerTier` in code.
#   2. Push → observability-watch.yml runs → detect-drift.py finds the rename.
#   3. A GitHub issue is opened: `Observability drift on refactor/camelcase-attrs`.
#   4. Open the issue. Click the one-line Claude Code resolver prompt.
#   5. Claude reads the ticket + observability-repair skill, proposes a deprecation-aware PR.
#   6. Push the branch; Weaver + dtctl CI runs green; the issue closes automatically.
set -euo pipefail

BR="refactor/camelcase-attrs"
log() { printf '\033[1;33m[scenario-2]\033[0m %s\n' "$*"; }

log "creating branch $BR"
git checkout -b "$BR" main

log "apply the naïve rename (no registry/dtctl updates on purpose)"
./demo-app/services/checkout/patches/rename-customer-tier.sh
git add -A
git commit -m "refactor(checkout): camelCase span attributes"
git push -u origin "$BR"

log "waiting for observability-watch.yml to file a drift issue"
ISSUE_NUM=""
for i in {1..24}; do
  ISSUE_NUM=$(gh issue list --label observability-drift --search "$BR" --json number -q '.[0].number' 2>/dev/null || echo "")
  [[ -n "$ISSUE_NUM" ]] && break
  sleep 5
done
[[ -n "$ISSUE_NUM" ]] || { echo "::error::watcher never filed an issue" && exit 1; }

log "drift issue filed: #$ISSUE_NUM"
gh issue view "$ISSUE_NUM"

log "handing off to Claude Code"
gh issue view "$ISSUE_NUM" > /tmp/ticket.md

claude code \
  --skill skills/observability-repair \
  --prompt "$(cat prompts/scenario-2-resolve-drift.md | sed -n '/^---PROMPT BELOW---$/,$ p' | tail -n +2)
TICKET:
$(cat /tmp/ticket.md)"

log "Claude should have produced a commit. Pushing..."
git push

log "watching CI after Claude's fix"
PR_URL=$(gh pr create --fill --label "observability" \
                      --body "Closes #$ISSUE_NUM. Resolved by Claude Code." 2>/dev/null \
         || gh pr view --json url -q .url)
gh pr checks "$PR_URL" --watch

log "merging + closing the drift ticket"
gh pr merge "$PR_URL" --squash --delete-branch
gh issue close "$ISSUE_NUM" --reason completed

log "done."
