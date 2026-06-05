---
description: Merge all ready (merge-awaiting) tracks into main, one at a time — rebase each onto the just-updated main, re-verify, cross-check, merge, close. Single-runner; prevents concurrent tracks from tangling.
argument-hint: "[optional: track id filter (t3,t5) — empty = all merge-awaiting tracks]"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(git status:*), Bash(git worktree list:*), Bash(git worktree remove:*), Bash(git log:*), Bash(git diff:*), Bash(git merge-base:*), Bash(git rev-list:*), Bash(git branch:*), Bash(git rebase:*), Bash(git merge:*), Bash(git -C:*), Bash(git pull --rebase:*), Bash(git add:*), Bash(git commit:*), Bash(git clean:*), Bash(git checkout:*)
---

# /track-merge — sequential merge orchestrator

Several tracks developed in parallel worktrees, each merged independently, tangle:
branches on a stale base, the shared registry/log racing, cross-integration breaking
(track A merges a rename, track B still calls the old name → crash *after* merge).

This command runs from **one place only (the `main` working tree)** and treats **all
`merge-awaiting` tracks as one queue, merging them one at a time**. Single execution
point ⇒ shared-file contention serializes naturally without locks, and each track is
**re-based onto the main that already includes the previous merge** — so any tangle
surfaces and is resolved *before* it lands.

Scope filter: $ARGUMENTS (empty = all `merge-awaiting` tracks)

## Premise: the main working tree need not be "clean", only "normal noise"

Running several tracks at once means `main`'s working tree always carries **active
tracks' doc changes** (`.tracks/<id>/` edits, the shared registry). This is normal and
is **not** a hard-clean target. Instead of "abort on any uncommitted change", classify
changes by owner: block only *unknown/non-active* changes; reflect each active track's
changes **when that track is merged**.

## Run preconditions (blocking)
- **Run from the `main` working tree, single instance.** If inside a worktree, or
  another `track-merge` is already running, stop. (The concurrency guard *is* "only one
  runs at a time" — no separate lock.)
- Uncommitted changes are triaged in step 0a (no hard-clean required).

---

## Step 0a — Working-tree triage (block only unknown changes)

1. `git status --porcelain` → collect every changed/untracked path.
2. Map each path to an owner:
   - `.tracks/<id>/**` → owned by track `<id>`.
   - shared root files (`.tracks/registry.md`, `.tracks/log.md`) → **shared**.
   - anything else (application code, files outside `.tracks/`) → **foreign**.
3. Judge against the registry:
   - **Any foreign path → STOP.** List them; ask the user to handle (commit/revert/assign
     to a track). The orchestrator never swallows changes of unknown origin.
   - An owning track **not in the registry**, or present but **Status ≠ active** (merged /
     abandoned / paused) → **STOP** and report. ("Changes for a non-active track" is a
     work-tree pollution signal.)
   - If the remaining changes are **only shared files + active-track docs → PASS.** This
     noise is normal; don't clear it. Each active track's changes are reflected when that
     track is merged (steps 1 & 4).
4. Append the triage result (pass / block reason) as one line to `.tracks/log.md`.

> One-liner: **active-track & shared noise = OK; foreign or non-active changes = STOP.**

---

## Step 0b — Build the merge queue + user confirm (the only approval gate)

1. **Collect candidates.** From `.tracks/registry.md`, read `active` rows. For each:
   - **ready signal** (primary): `.tracks/<id>/state.md` `Status:` is `merge-awaiting`.
   - **heuristic fallback**: no explicit signal but worktree exists + branch ahead of main
     (`git rev-list main..feat/<id>` ≥ 1) + state.md progress all done → list as candidate
     marked "(inferred)".
2. **Per-track readiness evidence**: ahead-count, base commit, `git merge-base feat/<id> main`,
   changed files, the state.md verify command + any `## Merge Risk Notes`.
   - Merge Risk Notes (shared files, API/signature changes, known concurrent tracks) are
     author-written and **complement** the automatic `git diff --name-only` overlap analysis
     (file-level) with function/signature-level risk. Empty notes are fine.
3. **Pre-gate (auto-exclude)** and report why:
   - branch ahead is 0 or no worktree → "nothing to merge".
   - (Add your own project gates here, e.g. base predates a structural cut that makes auto-rebase unsafe.)
4. **Cross-overlap analysis.** For each candidate pair, intersect changed files
   (`git diff --name-only main...feat/<id>`). Surface overlapping pairs + files.
5. **Auto-order (dependency/overlap).** Independent tracks (zero file overlap with others)
   first; overlapping tracks ordered oldest-base-first so conflicts cluster late and minimize.
   If a track was branched off another (stacked), the parent merges first. State the order + why.
6. **Present the whole queue and get ONE approval:**
   ```
   Merge queue (proposed order):
     1. t4  [clean]          feat/t4  ↑3  no overlap
     2. t2  [inferred]       feat/t2  ↑5  overlap: t5 (config, main entrypoint)
     3. t5  [merge-awaiting] feat/t5  ↑7  overlap: t2 (config, main entrypoint)
   Excluded: t1 (base too old — manual)
   Work-tree noise (left as-is): t6 docs (active), t8 docs (active)
   ```
   - On approval, proceed autonomously (stop only on the stop conditions below).
   - Append the approval to `.tracks/log.md`.
   - No `merge-awaiting` tracks → "nothing to merge" and stop.

---

## Steps 1..N — per-track merge loop (in approved order)

For each track `T` (worktree `W`, branch `feat/T`), in order:

### 0) Tidy T's working-tree noise (just before merging)
- T's **authoritative** docs are on `feat/T` (the worktree's single writer). The
  uncommitted/untracked T docs sitting in `main`'s tree are **superseded** by what the
  merge brings — that's the mechanism for "reflect this track when merging it".
- So `git merge feat/T` doesn't collide with untracked files, clear **only T-owned paths**
  in main's tree (`.tracks/T/`): tracked → `git checkout -- <path>`, untracked →
  `git clean -fd .tracks/T/`. **Never touch other tracks' noise.**
- ⚠️ **Information-loss guard**: before clearing, check whether the main-tree leftover holds
  anything NOT on `feat/T` (`git -C W show feat/T:<path>` / diff). If `feat/T` is authoritative,
  clear; if the leftover has unique content, **STOP** → ask which to keep.

### 1) Rebase onto latest main (the anti-tangle core)
- `git -C W rebase main` — put feat/T on top of the **current** main (includes the previous merge).
- **On conflict**:
  - Mechanical/obvious (import order, the same-direction edit to a rename the previous merge
    introduced) → resolve and `git -C W rebase --continue`.
  - **Semantic** (two tracks change the same logic with different intent) → **STOP**, show the
    user the conflict and ask.
- **⚠️ Post-conflict cross-logic verification (MANDATORY, only when a conflict occurred):**
  For every conflicted file, BEFORE continuing the rebase:
  1. Read the resolved file fully; list every identifier the rebased track's new code
     references (function calls, vars, imports, props, type fields).
  2. Confirm each is actually defined/imported in the merged result.
  3. Watch especially: if the previous track (main side) refactored this file (rename,
     signature change, split), check the rebased track's code was **adjusted to the new API**.
     e.g. main renamed `pinnedDate()`→`pinnedStart()`; if the rebased track's `isToday()`
     still calls `pinnedDate()`, rewrite it.
  4. If any identifier fails, fix in the file and re-check. **Never assume "git removed the
     conflict markers so it's fine."** git merges text; it does not verify logic.

### 2) Re-run verify (analyze + fix on failure)
- In W, actually re-run the track's verification (rebase may have changed code, so this is
  required). The command is the track's `state.md` `## Verify` line (e.g. `pytest -q`,
  `bun test`, a build + smoke). Run it in W.
- **On failure**: analyze. If it's a **cross-integration break** caused by the previous merge
  (stale reference / missed rename) → fix in W, fixup commit, re-verify. If it's a real
  regression in the track's own logic → **STOP**, report.

### 3) Merge into main
- feat/T now sits linearly on top of main, so this is conflict-free.
- `git merge --no-ff feat/T` (merge commit names the track id + summary). Step 1-0 cleared
  T-owned noise, so no untracked collision.

### 4) Close docs + reflect shared files (only now write shared files, once)
- In `.tracks/registry.md`, flip **only T's row** `active` → `merged`; record the merge sha.
  **Preserve every other active track's row** (their uncommitted registry edits, if any, are
  theirs — don't touch).
- `.tracks/T/state.md` `Status:` → `merged → main <sha> (date)`.
- Append **one line** to `.tracks/log.md`.
- **Close commit**: stage **only T paths + shared files** (`git add .tracks/T/`,
  `.tracks/registry.md`, `.tracks/log.md` by explicit path), so other tracks' noise doesn't
  ride along. Commit `docs(T): close track — merged (<sha>)`.

### 5) Cleanup
- `git worktree remove W` (after confirming it's clean).
- `git branch -d feat/T` (`-d` succeeds since it's merged).
- Remove leftover build artifacts under `.worktrees/T`.

### 6) Next track
- The next track's rebase goes onto the main that now includes T → overlaps/tangles surface
  there and are resolved the same way. Repeat until the queue is empty.

---

## Stop conditions (hand back to the human)
- Step 0a triage finds a **foreign** change or a **non-active/unregistered** track change.
- Step 1-0 main-tree leftover holds content not on feat/T → authoritative call needed.
- A **semantic** rebase conflict (not mechanically resolvable).
- Verify failure judged a **track-logic regression** (not a cross-integration break).
- A pre-gate exclusion the user asks to force anyway.
- Worktree/branch state unexpected (uncommitted changes on feat/T, detached HEAD).

Each stop holds **only the current track**; the rest of the queue continues after the
user decides. **Never roll back an already-merged track.**

## Final report
- Table: merged tracks (+sha), held tracks (+reason), excluded tracks (+reason).
- Cleaned worktrees/branches, updated registry rows, appended log lines.
- **Work-tree noise left untouched** (other still-active tracks' uncommitted docs) — state
  plainly that it's intentional.

## Operating rules
- Work tree only needs "normal noise" (active-track + shared). Don't hard-clean; block only
  foreign/non-active (step 0a).
- **Single writer.** Each track's state.md is written by that track only. The root registry/log
  are written by this command at merge time only (the one concurrent-write point, safe because
  single-instance).
- **Shared files reflected after merge.** Flip T's registry row to `merged` only after merging T.
- The log is **append-only** (never overwrite — causes duplication).
- Already-merged tracks are never reverted. Failures stop **at the current track** and report.
