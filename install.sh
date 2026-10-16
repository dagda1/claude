#!/usr/bin/env bash
# Install this repo's skills, agents, hooks and permissions into a project for Devin CLI.
# Usage: ./install.sh /path/to/project
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:?usage: ./install.sh /path/to/project}"
PROJECT="$(cd "$PROJECT" && pwd)"

mkdir -p "$PROJECT/.devin" "$PROJECT/.claude/commands"

# Skills are slash commands in Devin: .devin/skills/<name>/SKILL.md runs as /<name>.
ln -sfn "$REPO/skills" "$PROJECT/.devin/skills"
ln -sfn "$REPO/agents" "$PROJECT/.devin/agents"

# Stop hook for /build: blocks finishing while a spec check fails.
ln -sfn "$REPO/devin/hooks.v1.json" "$PROJECT/.devin/hooks.v1.json"

# Shared permissions: what /build needs runs without prompts; rm, push, reset, rebase ask;
# aws, dev servers and watch mode are denied. Per-project extras (for example
# Exec(pnpm --filter @app/web test)) go in .devin/config.local.json, which is not committed.
if [ -f "$PROJECT/.devin/config.json" ] && [ ! -L "$PROJECT/.devin/config.json" ]; then
  echo "NOTE: $PROJECT/.devin/config.json exists as a regular file — merge $REPO/devin/config.json into it."
else
  ln -sfn "$REPO/devin/config.json" "$PROJECT/.devin/config.json"
fi

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

# The remaining single-file workflows: Devin imports .claude/commands/*.md as skills.
for wf in "$REPO"/workflows/*.md; do
  ln -sfn "$wf" "$PROJECT/.claude/commands/$(basename "$wf")"
done

echo "Installed into $PROJECT/.devin:"
ls -la "$PROJECT/.devin" "$PROJECT/.claude/commands"
echo
echo "Restart any running Devin session in $PROJECT to pick up the skills."
