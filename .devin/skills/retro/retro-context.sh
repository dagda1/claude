#!/usr/bin/env bash
# retro-context.sh — collects the evidence a retro needs and prints only the parts that
# can show a problem: user messages, repeated failures, Stop-hook blocks, blocked items,
# findings that were not fixed, what the user changed, earlier retros and the Rules table.
# Usage: retro-context.sh    (the task is the current branch)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
TASK="$(git branch --show-current)"
[[ -n "$TASK" && "$TASK" != dev ]] || { echo "on dev or no branch: no task" >&2; exit 1; }
DIR="plans/$TASK"
[[ -d "$DIR" ]] || { echo "no task folder: $DIR" >&2; exit 1; }
LOG="$DIR/log.md"
touch_none() { [[ -n "$1" ]] && echo "$1" || echo "None."; }

echo "TASK=$TASK"

echo
echo "## User messages ($LOG)"
touch_none "$(grep -n ' user: ' "$LOG" 2>/dev/null || true)"

echo
echo "## Failed tool calls, most repeated first (count, call)"
touch_none "$(grep ' failed ' "$LOG" 2>/dev/null | sed -E 's/^- [0-9-]+ [0-9:]+ //' |
  cut -d'|' -f1 | sort | uniq -c | sort -rn || true)"

echo
echo "## Stop-hook blocks and build events"
touch_none "$(grep -nE 'stop (blocked|hook)|build ended' "$LOG" 2>/dev/null || true)"

echo
echo "## Blocked spec items"
touch_none "$(grep -nA3 '^- \[!\]' "$DIR/spec.md" 2>/dev/null || true)"

for review in test-review.md review.md; do
  echo
  echo "## Findings in $review not marked Fixed"
  touch_none "$(awk '
    /^### [0-9]+\.[0-9]+/ { head = $0; line = FNR; next }
    head != "" && /^Result: / { if ($0 !~ /^Result: Fixed/) print line ": " head "\n    " $0; head = "" }
  ' "$DIR/$review" 2>/dev/null || true)"
done

echo
echo "## Needs your decision (summary.md)"
touch_none "$(awk '/^## Needs your decision/ { on = 1; next } /^## / { on = 0 } on && NF' "$DIR/summary.md" 2>/dev/null || true)"

echo
echo "## What the user changed after the build"
touch_none "$(git status --short -- . ':!plans')"
git diff --stat -- . ':!plans' | tail -n 30

echo
echo "## Earlier retros: What went wrong"
found=""
while read -r f; do
  [[ "$f" == "$DIR/retro.md" ]] && continue
  found=1
  echo "### $f"
  awk '/^## What went wrong/ { on = 1; next } /^## / { on = 0 } on && /^- /' "$f"
done < <(git ls-files 'plans/*retro.md')
[[ -n "$found" ]] || echo "None."

echo
echo "## Rules table (AGENTS.md)"
touch_none "$(awk '/^## Rules/ { on = 1; next } /^## / { on = 0 } on && NF' AGENTS.md 2>/dev/null || true)"
