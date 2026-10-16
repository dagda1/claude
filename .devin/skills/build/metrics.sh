#!/usr/bin/env bash
# metrics.sh — one row of results for a task, counted from its files and git history.
# The numbers come from the files, not from the model.
#
# Usage:
#   metrics.sh <task>            print the row
#   metrics.sh --record <task>   write the row to plans/metrics.csv, replacing an older row for the task
#
# Counts: spec items from plans/<task>/spec.md, review rounds and `Result:` lines from
# review.md and test-review.md, reverts from `git revert` commits of the task's commits.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

record=0
if [[ "${1:-}" == "--record" ]]; then
  record=1
  shift
fi
task="${1:?usage: metrics.sh [--record] <task>}"

dir="plans/$task"
spec="$dir/spec.md"
review="$dir/review.md"
tests="$dir/test-review.md"
[[ -f "$spec" ]] || { echo "no spec: $spec" >&2; exit 1; }

count() {
  local n=0
  if [[ -f "$2" ]]; then
    n=$(grep -cE "$1" "$2" || true)
  fi
  echo "${n:-0}"
}

items=$(count '^- \[[ xX!]\] [0-9]+\.' "$spec")
done_items=$(count '^- \[[xX]\] [0-9]+\.' "$spec")
blocked=$(count '^- \[!\] [0-9]+\.' "$spec")
rounds=$(count '^## Round [0-9]+' "$review")
fixed=$(count 'Result: Fixed' "$review")
skipped=$(count 'Result: Skipped' "$review")
invalid=$(count 'Result: Invalid' "$review")
repeated=$(count 'Result: Repeated' "$review")
open=$(count 'Result: Open' "$review")
found=$((fixed + skipped + invalid + repeated + open))
test_findings=$(count 'Result: ' "$tests")
reverted=$(git log --all --format=%s -E --grep="^Revert \"(feat|fix)\\($task\\)" | wc -l | tr -d ' ')

header="date,task,items,done,blocked,rounds,found,fixed,skipped,invalid,repeated,open,test_findings,reverted"
row="$(date +%F),$task,$items,$done_items,$blocked,$rounds,$found,$fixed,$skipped,$invalid,$repeated,$open,$test_findings,$reverted"

if [[ $record -eq 0 ]]; then
  echo "$header"
  echo "$row"
  exit 0
fi

file="plans/metrics.csv"
if [[ ! -f "$file" ]]; then
  echo "$header" >"$file"
fi
tmp="$(mktemp)"
awk -F, -v t="$task" 'NR == 1 || $2 != t' "$file" >"$tmp"
echo "$row" >>"$tmp"
mv "$tmp" "$file"
echo "recorded in $file: $row"
