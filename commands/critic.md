---
description: "Adversarially review what you're building via an isolated critic subagent (cross-checks design/claims against the ACTUAL code), then fold valid findings back into the current work."
argument-hint: "[files/dir/topic to review — empty = current changes/docs]"
allowed-tools: Task, Read, Grep, Glob, Bash(git status:*), Bash(git diff:*)
---

Goal: have the thing you're building in **this session** adversarially reviewed by an
**isolated-context `critic` subagent** (cross-checking claims against the real codebase),
and fold valid findings back into the current work. (This is a Claude Code subagent — it
runs in a fresh context and returns its final message to this session; not a separate
process, not prompt injection.)

Review target: **$ARGUMENTS**
- If empty, target the current work (recently written/edited docs, files in `git status`/`git diff`).

Proceed in order:

1. **Fix the target & context.** From `$ARGUMENTS` (or current work), pick the concrete
   file/dir paths. Use `git status` if needed. Summarize in 1–2 sentences what you're
   building and why — the subagent **can't see this session's history**, so you must give
   it the context.

2. **Spawn the `critic` subagent (Task, `subagent_type: critic`).** Make the prompt
   self-contained:
   - One-line context: "Building/designing 〈what〉."
   - The **exact file paths** to review (so the subagent reads them) + **hints to the real
     code** to cross-check against (relevant modules/functions).
   - Instruction: "Find the bugs and design misses a human reading only the doc would
     skim past. **Verify the doc's assertions** ('safe', 'instant', 'no race',
     'auto-clears', 'idempotent') **against the actual code** and cite `path:line`.
     Classify HIGH/MEDIUM/LOW, lead with the top 1–2. No praise, no summary — actionable
     findings only."

3. **Fold the returned findings into this session.** When the result comes back:
   - **Summarize** the key findings to the user (the result isn't shown to them directly).
   - **Cross-check each against the code** — don't trust blindly (the subagent can be wrong too).
   - Classify valid ones: **engineering fixes** (apply now) vs **policy forks needing a user
     decision** (ask).
   - **Confirm with the user before any large change.**

Note: the `critic` subagent is read-only (Read/Grep/Glob/Bash); it does not edit code —
this (main) session applies the fixes.
