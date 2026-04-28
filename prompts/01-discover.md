# Deprecated — use `resolve-drift-ticket.md` instead

This prompt was part of the v2 storyboard ("AI builds your dashboard from scratch"). The episode pivoted: dashboards are now version-controlled YAML in `dtctl/` and applied by CI. Agents don't build them; they *repair* them when a Copilot-filed drift ticket demands it.

See:
- `prompts/resolve-drift-ticket.md` — the one prompt this episode uses
- `skills/observability-repair/SKILL.md` — the rules Claude follows
- `.github/workflows/observability-watch.yml` — the pipeline that files drift tickets
