#!/usr/bin/env python3
"""PreToolUse guard: block application-code edits on the *main* checkout while a
track is active.

Rationale: agent-tracks mandates a blocking "worktree gate" — no application code
may be generated outside a worktree. That rule lives in .tracks/rules.md
as prose and depends on the model's discipline, so edits can leak into main. This
hook makes the gate a hard, structural constraint.

Conditional enforcement: only blocks when the Track Registry has at least one
`active` track. With zero active tracks (e.g. initial setup, single-track solo
work), main edits pass through.

Always-allowed targets (never blocked):
  - anything under .worktrees/                (you're already in a worktree)
  - .tracks/                                  (track docs — the documentation layer)
  - .claude/                                  (settings / hooks / commands / agents)
  - any *.md file                             (docs, including README/CLAUDE.md)
  - paths outside the main checkout entirely

Escape hatch for an intentional main hotfix:
  set TRACKS_ALLOW_MAIN_EDIT=1 in the environment.

Blocking mechanism: exit code 2 + message on stderr (PreToolUse contract — the
tool call is denied and the message is shown back to the agent).
"""

import json
import os
import sys
from pathlib import Path

# main checkout root = three levels up from .claude/hooks/guard-main-edits.py
MAIN_ROOT = Path(__file__).resolve().parents[2]
REGISTRY = MAIN_ROOT / ".tracks" / "registry.md"

# path prefixes (relative to MAIN_ROOT) that are always editable on main
ALLOWED_PREFIXES = (
    ".worktrees/",   # actually a worktree, not main
    ".tracks/",      # track docs
    ".claude/",      # settings / hooks / commands / agents
)


def has_active_track() -> bool:
    """True if the Track Registry has any row whose Status cell is 'active'."""
    try:
        text = REGISTRY.read_text(encoding="utf-8")
    except OSError:
        # no registry → can't assert a track is active → don't block
        return False
    for line in text.splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = [c.strip() for c in line.split("|")]
        # table row: ['', 'ID', 'Title', 'Status', 'Branch', ...]
        if len(cells) < 4:
            continue
        if cells[3].lower().startswith("active"):
            return True
    return False


def main() -> int:
    if os.environ.get("TRACKS_ALLOW_MAIN_EDIT") == "1":
        return 0

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # fail-open on malformed input — never wedge the editor

    if payload.get("tool_name") not in ("Edit", "Write", "NotebookEdit"):
        return 0

    tool_input = payload.get("tool_input") or {}
    raw_path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if not raw_path:
        return 0

    try:
        target = Path(raw_path).resolve()
    except OSError:
        return 0

    # outside the main checkout → not our concern
    try:
        rel = target.relative_to(MAIN_ROOT).as_posix()
    except ValueError:
        return 0

    # always-allowed targets
    if rel.endswith(".md"):
        return 0
    if any(rel.startswith(p) for p in ALLOWED_PREFIXES):
        return 0

    # at this point: application code on the main checkout
    if not has_active_track():
        return 0  # no track in flight → allow

    sys.stderr.write(
        "BLOCKED by worktree gate (.tracks/rules.md): refusing to edit "
        f"main-checkout application code while a track is active.\n"
        f"  target: {rel}\n"
        "Do the work in the track's worktree (.worktrees/<id>/) instead — "
        "create/enter it first, then edit there.\n"
        "If this really is an intentional main hotfix outside any track, re-run "
        "with TRACKS_ALLOW_MAIN_EDIT=1 set in the environment.\n"
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
