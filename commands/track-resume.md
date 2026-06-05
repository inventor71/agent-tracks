---
description: Resume a track from where it left off, reconstructing state from its state.md + audit.md. Re-presents any pending gate instead of guessing.
argument-hint: "[optional: track id — empty = the sole active track, or asks which]"
allowed-tools: Read, Glob, Grep, Bash(git worktree list:*), Bash(git status:*)
---

# /track-resume — continue from the breakpoint

Pick up a track from the previous session **based on its state files**.

Resume target: $ARGUMENTS
(empty → the track arg if given; else the single `active` track. If several are active,
ask which to resume first.)

## Steps

1. **Load the rules.** `rules/concurrent-tracks.md`.
2. **Select the track + reconstruct position.** Read:
   - `.tracks/registry.md` — the track's branch/worktree.
   - `.tracks/<id>/state.md` — done/skipped/in-progress, the `## Verify` command, scope.
   - `.tracks/<id>/audit.md` **recent entries** — last user input/approval, next action.
   - `git worktree list` — confirm you're (or can get) in the track's worktree. If at a
     coding step with no worktree, create it first (code only inside the worktree).
3. **Summarize the resume point** in 2–4 lines: where it is, the last thing done and the
   **next thing to do**, and any gate (unanswered question / unapproved step) waiting.
4. **Gate check.** If the next step is a **pending approval** or an **unanswered question**,
   re-present it and stop — don't auto-advance. Otherwise continue the work.
5. **Record** this resume + the user's response in `.tracks/<id>/audit.md` (append).

## Notes
- If state is contradictory or ambiguous, **don't guess** — ask the user what's next.
- No `active` tracks → nothing to resume; suggest `/track-new`.
