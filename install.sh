#!/usr/bin/env bash
# Install this repo's skills, agents, hooks and permissions into a project for Claude Code.
# Usage: ./install.sh /path/to/project
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:?usage: ./install.sh /path/to/project}"
PROJECT="$(cd "$PROJECT" && pwd)"

mkdir -p "$PROJECT/.claude"

# Link a file or folder from this repo into the project. A real file or folder already
# there is left alone, with a note.
link() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "NOTE: $dest exists and is not a link — merge $src into it by hand."
  else
    ln -sfn "$src" "$dest"
  fi
}

# Skills run as slash commands: /spec, /build, /retro, /branch-review, /pr-message.
link "$REPO/skills" "$PROJECT/.claude/skills"
link "$REPO/agents" "$PROJECT/.claude/agents"

# Shared permissions and the hooks for /spec and /build: the Stop hook that keeps /build
# working while a check fails, and the hooks that write plans/<task>/log.md.
# Per-project extras go in .claude/settings.local.json, which is not committed.
link "$REPO/.claude/settings.json" "$PROJECT/.claude/settings.json"

# AGENTS.md is the canonical per-project context file; CLAUDE.md links to it.
if [ ! -e "$PROJECT/AGENTS.md" ]; then
  cp "$REPO/templates/AGENTS.md" "$PROJECT/AGENTS.md"
  echo "Created $PROJECT/AGENTS.md from template — edit it for this project."
fi
if [ ! -e "$PROJECT/CLAUDE.md" ]; then
  ln -s AGENTS.md "$PROJECT/CLAUDE.md"
elif [ ! -L "$PROJECT/CLAUDE.md" ]; then
  echo "NOTE: $PROJECT/CLAUDE.md exists as a regular file — merge it into AGENTS.md and replace with: ln -sf AGENTS.md CLAUDE.md"
fi

# Task files in plans/ are not committed, except retro.md.
if ! grep -qxF '/plans/*/*' "$PROJECT/.gitignore" 2>/dev/null; then
  printf '\n# /spec and /build task files; only retro.md is committed\n/plans/*/*\n!/plans/*/retro.md\n' >>"$PROJECT/.gitignore"
  echo "Added plans/ rules to $PROJECT/.gitignore."
fi

echo "Installed into $PROJECT/.claude:"
ls -la "$PROJECT/.claude"
echo
echo "Restart any running Claude Code session in $PROJECT to pick up the skills and hooks."
