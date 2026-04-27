#!/usr/bin/env python3
"""
Detect observability drift between two git refs.

Walks the code diff for span.set_attribute / metric creation / log fields and
compares the set of attribute names found in HEAD vs BASE. Cross-checks against
weaver/registry/ to flag:

  1. removed_from_code  — attribute disappeared from code, still in registry
  2. added_to_code      — attribute appeared in code, not in registry
  3. renamed            — a naive rename pair (e.g. customer.tier -> customerTier)

Output: JSON { "drifts": [ { "kind", "attribute", "location", "suggestion" }, ... ] }
"""
from __future__ import annotations
import argparse
import json
import pathlib
import re
import subprocess
import sys
from typing import Iterable


ATTR_PATTERNS = [
    # Python / Java / Node — OTel SDK call sites
    re.compile(r'set_attribute\(\s*["\']([a-zA-Z0-9_.\-]+)["\']'),
    re.compile(r'setAttribute\(\s*["\']([a-zA-Z0-9_.\-]+)["\']'),
    # Go SDK
    re.compile(r'attribute\.(?:String|Int|Float64|Bool)\(\s*["\']([a-zA-Z0-9_.\-]+)["\']'),
    # Span kind declarations we care about cross-checking with registry
    re.compile(r'start_as_current_span\(\s*["\']([a-zA-Z0-9_.\-]+)["\']'),
]


def run(*args: str) -> str:
    r = subprocess.run(args, capture_output=True, text=True, check=True)
    return r.stdout


def git_show(ref: str, path: str) -> str:
    """Return file content at ref, or '' if it doesn't exist there."""
    r = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def extract_attrs(source: str) -> set[str]:
    found: set[str] = set()
    for p in ATTR_PATTERNS:
        found.update(p.findall(source))
    return found


def load_registry_attrs(registry_dir: pathlib.Path) -> set[str]:
    """Scrape attribute ids from weaver registry YAML without a YAML lib."""
    attrs: set[str] = set()
    for yaml in registry_dir.rglob("*.yaml"):
        for line in yaml.read_text().splitlines():
            m = re.match(r'\s*-\s*id:\s*([a-zA-Z0-9_.\-]+)', line)
            if m:
                attrs.add(m.group(1))
            m = re.match(r'\s*-\s*ref:\s*([a-zA-Z0-9_.\-]+)', line)
            if m:
                attrs.add(m.group(1))
    return attrs


def naive_rename(removed: set[str], added: set[str]) -> list[tuple[str, str]]:
    """Find (old,new) pairs where one looks like a rename of the other.

    Very tolerant: treats '.', '_' and case as equivalent. Practitioners get
    the same naive detection Copilot would do — this is a heuristic, not proof.
    """
    def norm(s: str) -> str:
        return re.sub(r'[._\-]', '', s).lower()
    removed_map = {norm(x): x for x in removed}
    pairs: list[tuple[str, str]] = []
    for a in added:
        n = norm(a)
        if n in removed_map:
            pairs.append((removed_map[n], a))
    return pairs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-ref", required=True)
    ap.add_argument("--head-ref", required=True)
    ap.add_argument("--changed-files", required=True)
    ap.add_argument("--registry", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    changed = pathlib.Path(args.changed_files).read_text().strip().splitlines()
    code_files = [f for f in changed
                  if re.search(r'\.(py|ts|js|go|java)$', f)
                  and not f.startswith(('weaver/', 'dtctl/', '.github/'))]

    base_attrs: set[str] = set()
    head_attrs: set[str] = set()
    per_file: dict[str, set[str]] = {}

    for f in code_files:
        b = extract_attrs(git_show(args.base_ref, f))
        h = extract_attrs(git_show(args.head_ref, f))
        base_attrs |= b
        head_attrs |= h
        per_file[f] = h - b | b - h

    removed = base_attrs - head_attrs
    added   = head_attrs - base_attrs

    registry = load_registry_attrs(pathlib.Path(args.registry))

    drifts: list[dict] = []

    # 1. Rename suspects (cross reference removed ↔ added)
    for old, new in naive_rename(removed, added):
        drifts.append({
            "kind": "renamed",
            "attribute": f"{old} → {new}",
            "location": ", ".join(sorted(f for f, s in per_file.items() if old in s or new in s)),
            "suggestion": (
                f"Keep `{old}` in the registry marked `deprecated: true` with a one-release overlap. "
                f"Add `{new}` with `stability: experimental`. Emit both from the code for one release. "
                f"Update dtctl queries to `coalesce({old}, {new})`."
            ),
        })

    # 2. Added-to-code but not in registry
    for a in added - registry - {new for _, new in naive_rename(removed, added)}:
        drifts.append({
            "kind": "added_to_code",
            "attribute": a,
            "location": ", ".join(sorted(f for f, s in per_file.items() if a in s)),
            "suggestion": (
                f"Declare `{a}` in `weaver/registry/` with `stability: experimental` and a `brief`. "
                f"Run `weaver registry check` before pushing."
            ),
        })

    # 3. Removed-from-code but still in registry (and not a rename)
    pure_removed = removed - {old for old, _ in naive_rename(removed, added)}
    for a in pure_removed & registry:
        drifts.append({
            "kind": "removed_from_code",
            "attribute": a,
            "location": ", ".join(sorted(f for f, s in per_file.items() if a in s)),
            "suggestion": (
                f"Mark `{a}` `deprecated: true` in the registry for one release, then remove. "
                f"Do NOT remove it from the registry in this PR."
            ),
        })

    out = {"drifts": drifts}
    pathlib.Path(args.output).write_text(json.dumps(out, indent=2))
    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
