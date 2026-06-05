---
description: Read-only dashboard of all active tracks — status, next action, pending gates, worktree violations. Modifies nothing.
argument-hint: "[optional: track id to scope — empty = all active tracks]"
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git diff --stat:*), Bash(git worktree list:*), Bash(git rev-list:*)
---

# /track-status — progress dashboard (read-only)

Summarize the state of all parallel tracks at a glance. **Modifies no files.**

Scope: $ARGUMENTS (empty = all `active` tracks)

## Collect

0. **Registry.** From `.tracks/registry.md`, read the track list (id/title/status/branch/
   worktree). Scope to the arg if given, else all `active` tracks.
1. **Per-track state.** `.tracks/<id>/state.md`: scope, done/skipped/in-progress items,
   `Status:` (active / merge-awaiting), the `## Verify` command.
2. **Next action & gates.** From `.tracks/<id>/audit.md` recent entries: last completed step,
   next action, any **pending approval/question** waiting on the user.
3. **Ahead count.** `git rev-list --count main..feat/<id>` — commits not yet on main.
4. **Worktree & violations.** `git worktree list` for each track's worktree;
   `git status` / `git diff --stat` for uncommitted size. **Flag**: uncommitted **code**
   in the `main` working tree = worktree-gate violation ⚠️.

## Output

```
# Tracks — <repo>

Registry: <id:status …>
⚠️ worktree violation: <uncommitted code on main — omit if none>

── <id> · <title> ── [<branch> @ <worktree>]  ↑<ahead>
Status: <active / merge-awaiting>
  ✅ done: <…>
  ⏳ in progress: <…>
  ⏭️  skipped: <… + reason>
🚦 pending gate: <approval / unanswered question — "none" if clear>
🔎 verify: <command>
➡️  next: <one line>

── <next active track> ──
…

📦 work tree (all): <changed files, +/- lines>
```

- One block per `active` track (or just the scoped one).
- Missing artifact → "n/a" for that line.
- No `active` tracks → "no tracks in progress — start one with /track-new".
