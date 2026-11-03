#!/usr/bin/env bash
# pr-context.sh — prints the short context a PR message needs, without the full diff:
# the house style, the commit subjects, the changed files, and the spec goal and items
# when plans/<branch>/spec.md exists.
# Usage: pr-context.sh [base]    (base defaults to dev)
set -euo pipefail

BASE="${1:-dev}"
cd "$(git rev-parse --show-toplevel)"
git fetch -q origin "$BASE"
MERGE_BASE="$(git merge-base "origin/$BASE" HEAD)"
BRANCH="$(git branch --show-current)"

echo "MERGE_BASE=$MERGE_BASE"
echo "MESSAGE_FILE=${TMPDIR:-/tmp}/pr-message-$(echo "$BRANCH" | tr '/' '-').md"
echo
echo "## House style: last 10 subjects on $BASE"
git log --format=%s -10 "origin/$BASE"
echo
echo "## Commits on this branch"
git log --format=%s "$MERGE_BASE..HEAD"
echo
echo "## Changed files"
git diff --stat "$MERGE_BASE..HEAD"

SPEC="plans/$BRANCH/spec.md"
if [[ -f "$SPEC" ]]; then
  echo
  echo "## Spec goal and items"
  awk '/^## (Goal|Items)/ { on = 1; print; next } /^## / { on = 0 } on' "$SPEC"
fi
