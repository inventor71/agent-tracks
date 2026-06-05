# Concurrent Tracks — the rules

The discipline that lets **several AI agents work the same repo in parallel without
stepping on each other**, and lets their results land on `main` in a controlled,
serialized way.

## Why this exists

When you run multiple long-lived agent sessions against one repo, they collide on
two things:

1. **Shared mutable files** — a status file, a task list, a changelog. Two sessions
   read-then-write and clobber each other.
2. **Stale-base merges** — each branch was cut from an old `main`; merging them
   independently tangles (one merge breaks another's assumptions, cross-integration
   regressions surface *after* the fact).

This ruleset removes both hazards with one idea + one orchestrator.

## Core principle: partition, don't lock

> **Every state file has exactly one writer. No file locks.**

File locks are the wrong tool for git-backed docs edited by a human+agent loop (stale
locks when an agent dies, no clean cross-worktree "wait"). Instead, **eliminate shared
mutable state** by giving each track its own files. The only file multiple tracks ever
touch is a thin **registry**, edited just twice per track (create + close) — rare
enough to resolve with `git pull --rebase`.

## What a "track" is

- A **track** = one parallel effort (a feature, fix, refactor, or deprecation),
  developed in its **own git worktree on its own branch**.
- Each track has a stable **id** (`t1`, `t2`, … — or prefix by kind: `f1` feature,
  `r1` refactor, `d1` deprecate). Next id = max existing + 1.
- A track owns exactly one branch and one worktree.

## File layout

```
<repo>/
├── .tracks/
│   ├── registry.md          # the Track Registry (thin index table). Rarely edited.
│   ├── log.md               # GLOBAL timeline. Append-only, written ONLY at merge.
│   ├── _template/
│   │   ├── state.md         # copy this to start a track
│   │   └── audit.md
│   └── <id>/
│       ├── state.md         # this track's full progress / scope / verify command
│       └── audit.md         # this track's append-only log (raw user input, ISO 8601)
└── .worktrees/<id>/         # the track's git worktree (gitignored)
```

- **Per-track docs all live under `.tracks/<id>/`** and are authored **in the worktree**
  so `main` stays clean. The single writer is that track's worktree session.
- **`.tracks/registry.md`** = the Track Registry table (below). A row is written at
  track **create** and flipped at **merge/close** — the only two cross-track edits.
- **`.tracks/log.md`** = a global cross-track timeline. A track appends to it **only at
  merge** (one line), never mid-flight — so there is no concurrent-append race.

## Track Registry (`.tracks/registry.md`)

A single table is the authority for which tracks exist and where they live:

```markdown
| ID | Title | Status | Branch | Worktree | Base | Updated |
|----|-------|--------|--------|----------|------|---------|
| t1 | … | active | feat/t1 | .worktrees/t1 | <sha> | 2026-… |
```

- `Status` ∈ `active` / `merged` / `abandoned`, plus the transient **`merge-awaiting`**
  a track sets on **its own** `.tracks/<id>/state.md` when its work is verified and ready
  (the standard hand-off — `track-merge` reads this to build its queue). The registry row
  stays `active` until `track-merge` flips it to `merged` at actual merge time.

## The worktree gate

**No application code is generated outside a worktree.** Treat it as a hard rule:
if you're about to edit code while checked out on `main`, stop — create the track's
worktree first (`track-setup.sh <id>` or `git worktree add .worktrees/<id> -b feat/<id>`).
Docs (`.tracks/<id>/`) may be authored before the worktree exists; code may not.

## Track lifecycle

1. **Create** (`/track-new`): pick the next id, copy `_template/` → `.tracks/<id>/`,
   add a registry row (`active`), create the worktree.
2. **Work**: all progress/audit/artifacts go under `.tracks/<id>/` only. Never touch
   another track's files or the root files (except your own registry row at create/close).
   Each track declares how to verify itself in its `state.md` `## Verify` section.
3. **Hand off**: when the work passes its own verification, set the track's `state.md`
   `Status:` to `merge-awaiting`. This enqueues it for `track-merge`.
4. **Merge / close** (`/track-merge`): a single-runner orchestrator merges all
   `merge-awaiting` tracks sequentially — rebase each onto the just-updated `main`,
   re-verify, merge, flip the registry row to `merged`, append one line to the global
   log, and remove the worktree + branch.

## What stays global / shared

- The **Track Registry** (`.tracks/registry.md`).
- The **global timeline** (`.tracks/log.md`) — merge-time appends only.
- These rule files themselves (changing the process is its own track).

## Quick checklist for any agent starting work

- [ ] Am I in a worktree for my track? If coding and on `main` → stop, create the worktree.
- [ ] Does my track have `.tracks/<id>/{state.md,audit.md}`? If not → create from `_template` + register.
- [ ] Am I about to edit the root registry/log mid-flight? → Don't. Use my track files.
- [ ] Did I record the verify command in my `state.md`? `track-merge` will run it on rebase.
