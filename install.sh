#!/usr/bin/env bash
# Install this repo's skills and workflows into a target project.
# Usage: ./install.sh /path/to/project
set -euo pipefail

CLAUDE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${1:?usage: ./install.sh /path/to/project}"
PROJECT="$(cd "$PROJECT" && pwd)"

mkdir -p "$PROJECT/.claude/commands" "$PROJECT/.devin/workflows"

ln -sfn "$CLAUDE_REPO/skills" "$PROJECT/.claude/skills"

for wf in "$CLAUDE_REPO"/workflows/*.md; do
  name="$(basename "$wf")"
  ln -sfn "$wf" "$PROJECT/.claude/commands/$name"
  ln -sfn "$wf" "$PROJECT/.devin/workflows/$name"
  chars=$(wc -c < "$wf")
  if [ "$chars" -gt 12000 ]; then
    echo "WARNING: $name is $chars chars — Cascade workflows are capped at 12000; trim it or it will be rejected in Devin."
  fi
done

echo "Installed into $PROJECT/.claude and $PROJECT/.devin:"
ls -la "$PROJECT/.claude/skills" "$PROJECT/.claude/commands" "$PROJECT/.devin/workflows"
echo
echo "Restart any running Claude Code / Devin session in $PROJECT to pick up the commands."
