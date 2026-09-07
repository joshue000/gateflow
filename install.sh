#!/usr/bin/env bash
# Idempotent: symlinks this repo's claude/skills/* and claude/agents/*.md into
# ~/.claude/{skills,agents} so they're globally discoverable. Safe to re-run
# after any edit — existing correct symlinks are left alone, stale ones are
# replaced, real (non-symlink) files at the target are never overwritten.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$ROOT/claude/skills"
AGENTS_SRC="$ROOT/claude/agents"
SKILLS_DST="$HOME/.claude/skills"
AGENTS_DST="$HOME/.claude/agents"

link() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "SKIP $dst — real file/dir exists, not a symlink. Move it aside and re-run." >&2
    return
  fi
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

mkdir -p "$SKILLS_DST" "$AGENTS_DST"

for dir in "$SKILLS_SRC"/*/; do
  name="$(basename "$dir")"
  link "$dir" "$SKILLS_DST/$name"
done

for file in "$AGENTS_SRC"/*.md; do
  name="$(basename "$file")"
  link "$file" "$AGENTS_DST/$name"
done

echo "Done. Verify: ls -la '$SKILLS_DST' '$AGENTS_DST'"
