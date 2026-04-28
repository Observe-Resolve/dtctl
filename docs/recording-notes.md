# Recording notes — Ep. 09

Production checklist for the day of recording. Pair with `02_teleprompter_script.md`.

## Pre-flight (do once, day before)

- [ ] Tenant ready: empty Dynatrace SaaS Gen3 environment, no dashboards/SLOs/workflows attributable to `observe-and-resolve`.
- [ ] OAuth client created, dtctl logged in: `dtctl auth verify` returns OK.
- [ ] OTel demo deployed and *idle* for ≥ 15 min so traffic baselines are stable.
- [ ] All four prompts dry-run end-to-end successfully on the recording machine.
- [ ] Slack channel `#oncall-ep9` created. Workflow's webhook tested with a manual ping.
- [ ] Chaos script tested — fault injects, alert fires, recovery returns to green inside 3 min.

## Audio + video

- [ ] Camera: Sony ZV-E10 (or equivalent), 4K30, locked white balance.
- [ ] Lavalier mic: Rode Wireless Go II, gain set so peaks hit -12 dB.
- [ ] Room: same as Ep. 08 for visual continuity (left-side fill, kicker on the bookshelf).
- [ ] Screen capture: OBS, 1920×1080, 30 fps, MP4. Show only the relevant app — no Slack DMs, no email.
- [ ] Terminal: dark theme, font 16pt minimum, full-screen. Hide hostname/cwd in PS1.
- [ ] Browser: dedicated Chrome profile with no extensions visible. Bookmarks bar hidden.

## Take order (record out of sequence to save time)

1. **All terminal/UI captures first** (no host audio).
   - Dashboard build sequence (Act 2) — record clean and speed-ramp in post.
   - Chaos injection + alert fire (Act 3).
   - Discovery DQL queries (Act 1).
2. **Talking head passes last**, so you can adjust pacing once you know how long the captures land.
3. **Cold open** — record 2 takes, pick the punchier one.

## Editing notes

- Speed-ramp the Act 2 dtctl scroll to **2× then 3× then back to 1×** — the bursty pace creates energy.
- Keep success lines (green ✓) on screen ≥ 1.2s. Everything else can blur.
- Music dips to a low bed for the 3-takeaways recap. Silence between bullets makes them feel earned.
- End card: subscribe button on the left, next-episode thumbnail on the right. Card holds for 12s.

## Chapters (paste into YouTube description)

```
00:00  The stakes — empty Dynatrace, live traffic
00:45  One prompt, one repo, go
01:15  What's running: OTel demo on K8s
02:15  Act 1 · Discover — MCP is the agent's eyes
03:30  Bonus: agent also patches the code
04:15  Act 2 · Build — dtctl is the agent's hands
06:00  Act 3 · Break it on purpose (alert fires)
06:45  3 things you just learned
07:30  Grab the repo and try it tonight
```

## Backup if the live demo fails

If the agent fumbles or the chaos script doesn't trigger the alert mid-take, roll the **pre-recorded fallback** at `./recording/fallback-act3.mp4`. The voiceover script is identical. Mention nothing on camera.

## Post-publish

- [ ] Pin a comment with the repo link.
- [ ] Add a community post day-of with the 3 takeaways.
- [ ] Cross-post the LinkedIn carousel from `./recording/social/`.
