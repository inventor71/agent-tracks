# Track Registry

<!-- TEMPLATE: This file is an initial template. Rows are added by /track-new (create)
     and flipped by /track-merge (close). Replace the example row below on first use. -->

The authority for which tracks exist and where they live. Edit a row only at track
**create** and **merge/close** (the only cross-track writes — serialize with
`git pull --rebase` before committing). Everything else lives in `.tracks/<id>/`.

| ID | Title | Status | Branch | Worktree | Base | Updated |
|----|-------|--------|--------|----------|------|---------|
| <id> | <title> | active | feat/<id> | .worktrees/<id> | <sha> | <date> |

<!-- Status: active / merge-awaiting (on the track's own state.md) / merged / abandoned -->
