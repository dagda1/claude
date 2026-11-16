#!/usr/bin/env bash
# pr-context.sh — prints the short context a PR message needs, without the full diff:
# the house style, the commit subjects and the changed files.
# Usage: pr-context.sh [base]    (base defaults to the remote's default branch)
set -euo pipefail

BASE="${1:-$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')}"
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
