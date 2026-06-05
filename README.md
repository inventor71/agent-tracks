# agent-tracks

**Merge discipline for concurrent AI agents.** Run several Claude Code sessions on the
same repo in parallel — each on its own isolated *track* — and land their work on `main`
through one serialized, self-verifying merge queue that won't let them tangle.

> Git worktrees let you run agents in parallel. The hard part isn't *splitting* the work —
> it's *recombining* it without one agent's merge silently breaking another's. That
> recombination is what this gives you.

---

## The problem

You point three agents at one repo to work three features at once. Then:

- They fight over shared files — a status file, a task list, a changelog. Two sessions
  read-then-write and clobber each other.
- Their branches were each cut from an old `main`. Merging them independently tangles:
  agent A merges a rename, agent B still calls the old name → it compiles, merges, and
  **breaks after the fact**.

## The idea (two parts)

**1. Partition, don't lock.** Every state file has exactly one writer. Each track keeps
all its docs under `.tracks/<id>/` (single-writer = that track's worktree session). The
only shared file is a thin **registry**, touched twice per track (create + close). No
locks, no clobber.

**2. One serialized merge runner.** `/track-merge` runs from a single place and treats all
ready tracks as one queue. For each track, in order, it:

```
rebase onto the main that already includes the previous merge
  → re-run the track's own verify command
  → on conflict: cross-check that the rebased code still references real identifiers
                 (git merges text; it does NOT verify logic)
  → merge --no-ff → flip registry row to merged → append one log line → remove worktree
```

Because every track re-bases onto the *latest* main and re-verifies, a tangle surfaces
**before it lands**, at the exact track that caused it — not three merges later.

## Quick start

This repo **is** a drop-in for Claude Code. Clone and run the install script to copy
`.claude/` and `.tracks/` into your project:

```
git clone https://github.com/<you>/agent-tracks.git
cd agent-tracks
./install.sh /path/to/your-project
```

Or copy by hand — the structure mirrors the target directly:

```
your-repo/
├── .claude/
│   ├── commands/   ← track-new.md, track-merge.md, track-status.md, track-resume.md, critic.md
│   ├── agents/     ← critic.md (adversarial reviewer subagent)
│   └── hooks/      ← guard-main-edits.py (blocks main-tree code edits while a track is active)
└── .tracks/
    ├── rules.md    ← the discipline every command loads
    ├── registry.md ← thin index of all tracks
    ├── log.md      ← global timeline (merge-time appends only)
    └── _template/  ← state.md + audit.md (copied to start each track)
```

`.tracks/` ships as a template — real data is populated on your first `/track-new` and
`/track-merge`.

Then point your project's `CLAUDE.md` at the rules so every session obeys them:

```markdown
## Parallel work
This repo uses agent-tracks for concurrent work. Load and obey
`.tracks/rules.md`. Never generate code outside a track worktree.
```

The guard hook (`guard-main-edits.py`) enforces the worktree gate at the tool level —
it blocks `Edit`/`Write` calls to application code on `main` whenever the Track Registry
has an active track. Set `TRACKS_ALLOW_MAIN_EDIT=1` to bypass for intentional main hotfixes.

## Workflow

```
/track-new  "add user authentication"          # creates t1: worktree + branch + docs + registry row
   … agent works inside .worktrees/t1, keeps progress in .tracks/t1/ …
   … when its Verify command passes, it sets state.md Status: merge-awaiting …

/track-status                                 # read-only dashboard of all active tracks

/track-merge                                  # queue all merge-awaiting tracks, merge serially
```

Run `/track-new` in as many sessions as you have features. Run `/track-merge` from **one**
session when you're ready to land them.

## Commands

| Command | What it does |
|---|---|
| `/track-new <desc>` | Start a track: assign id, scaffold `.tracks/<id>/`, register, create the worktree+branch. |
| `/track-merge [ids]` | **The orchestrator.** Triage the tree, build the queue, then rebase→verify→cross-check→merge→close each ready track in order. |
| `/track-status [id]` | Read-only dashboard: per-track status, next action, pending gates, worktree-gate violations. |
| `/track-resume [id]` | Reconstruct a track's state and continue; re-presents any pending gate instead of guessing. |
| `/critic [target]` | Spawn an isolated adversarial reviewer over your current work; fold valid, code-verified findings back in. |

## Conventions

- **Track id**: `t1`, `t2`, … (or prefix by kind: `f` feature, `r` refactor, `d` deprecate).
- **`merge-awaiting`**: a track sets this on its own `state.md` when verified & ready — the
  hand-off signal `/track-merge` reads. The registry row stays `active` until merge.
- **Verify command**: each track declares one in `state.md` `## Verify`. `/track-merge`
  re-runs it after rebasing onto the latest main — this is what catches cross-integration breaks.
- **Worktree gate**: code is only ever generated inside a track's worktree; `main` stays clean.

## Why a single merge runner (not "each agent merges itself")

If each agent merges its own branch, they all merge onto whatever `main` they last saw —
stale bases, racing on the registry, cross-integration breaks discovered in production.
A single runner serializes the one genuinely-shared step. It's the difference between
"three agents that produce work" and "three agents whose work actually composes."

## Origin

Extracted from a per-track customization of [AWS AI-DLC](https://github.com/awslabs/ai-driven-dev-lifecycle),
generalized to be framework-agnostic. The track lifecycle here is deliberately thin — bring
your own planning/design process on top; agent-tracks only owns **isolation + recombination**.

For the full AI-DLC workflow rules reworked around the concurrent-track philosophy (the
original customization this was extracted from), see
[aidlc-workflows-concurrent](https://github.com/inventor71/aidlc-workflows-concurrent) —
every phase from workspace detection through build-and-test made track-aware.

## License

MIT — see [LICENSE](LICENSE).
