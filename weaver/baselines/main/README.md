# Baselines

This directory holds a frozen snapshot of `weaver/registry/` as it was on `main` when the last release was tagged. It exists so `weaver registry diff` has something to compare against on every pull request.

## How it stays fresh

After every tagged release, `release.yml` runs `scripts/freeze-baseline.sh`, which copies the current registry into `main/` and commits it back to the repo via a bot PR. This guarantees the next PR's `registry diff` is comparing against the state of the world at the last release — which is the semantic version contract consumers rely on.

## Manual refresh

If you ever need to rebuild it locally:

```bash
./scripts/freeze-baseline.sh
git add weaver/baselines/main
git commit -m "chore(weaver): freeze baseline @ $(git describe --tags)"
```

## Files

The files in this directory mirror the structure of `weaver/registry/` — one YAML per domain (checkout, payment, cart, etc.). Do not edit them by hand.
