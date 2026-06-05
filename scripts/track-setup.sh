#!/usr/bin/env bash
# track-setup.sh — create (or reuse) a git worktree for a track.
#
#   scripts/track-setup.sh <id> [base-ref]
#
# Creates .worktrees/<id> on a new branch feat/<id> off <base-ref> (default: current
# HEAD of the main working tree). Idempotent-ish: if the worktree already exists it
# reports and exits non-zero (the id is taken — re-number).
#
# This is the framework-agnostic bootstrap. Add project-specific steps (dep install,
# linking env files, etc.) below the marked section as needed.
set -euo pipefail

id="${1:?usage: track-setup.sh <id> [base-ref]}"
base="${2:-HEAD}"
wt=".worktrees/${id}"
branch="feat/${id}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

echo "▶ Track '${id}' worktree bootstrap"
echo "  repo:     ${repo_root}"
echo "  worktree: ${wt}  (branch ${branch})"

if git worktree list | grep -q "/${wt}\b" || [ -d "$wt" ]; then
  echo "✗ worktree '${wt}' already exists — the id is taken. Re-number." >&2
  exit 1
fi
if git show-ref --quiet "refs/heads/${branch}"; then
  echo "✗ branch '${branch}' already exists. Re-number or delete it first." >&2
  exit 1
fi

git worktree add "$wt" -b "$branch" "$base"
echo "  • worktree created at ${wt} (branch ${branch} off ${base})"

# ── project-specific setup (optional) ────────────────────────────────────────
# e.g. install deps so the worktree is verifiable in place:
#   ( cd "$wt" && npm ci )            # or: bun install --frozen-lockfile
#   ( cd "$wt" && uv sync )           # or: pip install -e .
# e.g. link a local env file the app needs:
#   ln -sf "${repo_root}/.env" "${wt}/.env"
# ─────────────────────────────────────────────────────────────────────────────

echo "✔ '${id}' ready at ${wt}"
