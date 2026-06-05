#!/usr/bin/env bash
# install.sh — drop agent-tracks into any Claude Code project.
#
#   ./install.sh [target-project-path]
#
# Copies .claude/{commands,agents,hooks} and .tracks/ into the target.
# Safe: warns on existing files but merges directories.
set -euo pipefail

target="${1:-.}"
target="$(realpath "$target")"
src="$(cd "$(dirname "$0")" && pwd)"

# -- git repo check (works for both regular clones and worktrees) ----------------
if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
  echo "✗ target '$target' is not a git repository." >&2
  echo "  Initialize a git repo first, then re-run." >&2
  exit 1
fi

echo "▶ agent-tracks → ${target}"
echo "  source: ${src}"

# ── .claude ──────────────────────────────────────────────────────────────────
echo "  • .claude/commands/"
mkdir -p "$target/.claude/commands"
for f in "$src/.claude/commands/"*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [ -f "$target/.claude/commands/$base" ]; then
    echo "    ⚠ skipping $base (already exists)"
  else
    cp "$f" "$target/.claude/commands/"
    echo "    ✔ $base"
  fi
done

echo "  • .claude/agents/"
mkdir -p "$target/.claude/agents"
for f in "$src/.claude/agents/"*.md; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [ -f "$target/.claude/agents/$base" ]; then
    echo "    ⚠ skipping $base (already exists)"
  else
    cp "$f" "$target/.claude/agents/"
    echo "    ✔ $base"
  fi
done

echo "  • .claude/hooks/"
mkdir -p "$target/.claude/hooks"
hook_copied=false
for f in "$src/.claude/hooks/"*.py; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  if [ -f "$target/.claude/hooks/$base" ]; then
    echo "    ⚠ skipping $base (already exists)"
  else
    cp "$f" "$target/.claude/hooks/"
    echo "    ✔ $base"
    hook_copied=true
  fi
done

# ── .tracks ──────────────────────────────────────────────────────────────────
echo "  • .tracks/"
if [ -d "$target/.tracks" ]; then
  echo "    ⚠ .tracks/ already exists — merging (existing files kept)"
  for item in "$src/.tracks"/*; do
    base="$(basename "$item")"
    if [ ! -e "$target/.tracks/$base" ]; then
      cp -r "$item" "$target/.tracks/"
      echo "    ✔ $base"
    else
      echo "    ⚠ skipping $base (already exists)"
    fi
  done
else
  cp -r "$src/.tracks" "$target/.tracks"
  echo "    ✔ $(ls "$src/.tracks" | tr '\n' ' ' | sed 's/ $//')"
fi

# ── .gitignore: ensure .worktrees/ is excluded ───────────────────────────────
if ! grep -q '^\.worktrees/' "$target/.gitignore" 2>/dev/null; then
  echo "" >> "$target/.gitignore"
  echo "# agent-tracks worktrees" >> "$target/.gitignore"
  echo ".worktrees/" >> "$target/.gitignore"
  echo "  ✔ appended .worktrees/ to .gitignore"
else
  echo "  ⚠ .worktrees/ already in .gitignore"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✔ agent-tracks installed to ${target}"
echo ""
echo "── Add to ${target}/CLAUDE.md ──"
echo ""
echo '## Parallel work'
echo 'This repo uses agent-tracks for concurrent work. Load and obey'
echo '`.tracks/rules.md`. Never generate code outside a track worktree.'
echo ""
echo "── Hook activation ──"
if $hook_copied; then
  echo "guard-main-edits.py was copied to .claude/hooks/."
else
  echo "guard-main-edits.py was already present in .claude/hooks/ (not overwritten)."
fi
echo "Claude Code auto-discovers hooks there on next launch."
echo "To bypass for a hotfix: TRACKS_ALLOW_MAIN_EDIT=1"
