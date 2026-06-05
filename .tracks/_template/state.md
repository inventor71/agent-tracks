# Track <id> — <title>

> Per-track state. **Single writer = this track's worktree session.** Never edit another
> track's state; don't put this detail in `.tracks/registry.md` (registry = thin index only).
> See `rules/concurrent-tracks.md`.

## Track Info
- **ID**: <id>
- **Title**: <one line>
- **Kind**: feature | fix | refactor | deprecate
- **Status**: active  <!-- active → merge-awaiting (set when verified & ready) → merged (by /track-merge) -->
- **Branch**: feat/<id>
- **Worktree**: .worktrees/<id>
- **Base commit**: <parent sha at branch creation>
- **Started**: <ISO 8601>

## Scope
<what this track will build/change>

## Verify
<the exact command that proves this track works — /track-merge re-runs it after rebase.>
<e.g. `pytest -q`  |  `npm test`  |  `make check && ./smoke.sh`>

## Merge Risk Notes
> Filled when flipping to `merge-awaiting`. /track-merge reads this to build the queue /
> resolve conflicts beyond what `git diff --name-only` shows. Leave empty to rely on the
> automatic file-overlap analysis.

- **Shared files (watch)**: <files likely to overlap another active track>
- **API / signature changes**: <renames, deletes, splits other tracks must adjust to on rebase>
- **Known concurrent edits**: <other track ids touching the same files>

## Progress
- [ ] <step>
- [ ] <step>
