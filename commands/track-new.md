---
description: Start a new parallel track — assign an id, create its docs from the template, register it, and create its git worktree+branch. The front door for any new feature/fix/refactor.
argument-hint: "<short description of the work> [optional: kind = feature|fix|refactor|deprecate]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git worktree add:*), Bash(git worktree list:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(mkdir:*), Bash(cp:*), Bash(git pull --rebase:*)
---

# /track-new — start a parallel track

Create an isolated track for a new piece of work so it can run alongside other tracks
without colliding. Load and obey `rules/concurrent-tracks.md`.

Request: $ARGUMENTS

## Steps

1. **Pick the next id** from the **union of live sources** — `git worktree list`,
   `git branch --list 'feat/*'`, `ls .tracks/`, and the registry table — NOT a cached
   snapshot (other sessions claim ids concurrently). Use `t<n>` (or a kind prefix:
   `f`/`r`/`d`). Guard against collision: if `git worktree list | grep -q <id>` or
   `.tracks/<id>` already exists, **stop and re-number**.

2. **Create the track docs.** `mkdir .tracks/<id>`, copy `_template/{state.md,audit.md}`
   into it (only when the dir is absent — `cp -r` into an existing dir nests a stray
   `_template/`). Fill `state.md`: id, title, kind, branch `feat/<id>`, worktree
   `.worktrees/<id>`, base commit (`git rev-parse --short HEAD`), and a one-line scope.

3. **Record the request** verbatim (raw user input) in `.tracks/<id>/audit.md` (append,
   ISO 8601 — never summarize, never overwrite).

4. **Register** a row in `.tracks/registry.md` (`active`). This is a cross-track edit —
   `git pull --rebase` first if the repo has a remote, then add the row.

5. **Worktree gate.** Create the worktree **before** generating any code:
   `git worktree add .worktrees/<id> -b feat/<id>` (or `scripts/track-setup.sh <id>`).
   Design/planning docs may be authored before this; **code may not**. If you ever find
   yourself about to edit code on `main`, stop and create the worktree first.

6. **Declare verification.** In `state.md` `## Verify`, write the exact command that proves
   this track works (e.g. `pytest -q`, `bun test`, `make check`). `track-merge` re-runs it
   after rebasing onto the latest main.

7. **Proceed** with the work inside the worktree. Keep all progress in `.tracks/<id>/`.
   When verification passes, set `state.md` `Status:` to `merge-awaiting` to enqueue for
   `/track-merge`.
