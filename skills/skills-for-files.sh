#!/usr/bin/env bash
# skills-for-files.sh — deterministic skill selection for a set of changed files.
# The model never decides which rules load; this script does.
#
# Usage:
#   skills-for-files.sh file1 file2 ...        # union of skills for these files
#   git diff --name-only main... | skills-for-files.sh   # from stdin
#   skills-for-files.sh --per-file f1 f2       # show the mapping per file
#
# Output: one skill name per line (union, deduped). Pipe through
#   sed "s|^|.claude/skills/|;s|$|/SKILL.md|"
# to get paths to read.
#
# The map lives in skills-map.txt next to this script:
#   <extended-glob>[|<extended-glob>...] : skill skill skill
# First matching line wins per file, except lines starting with "+" which
# ALWAYS apply when matched (additive), checked after the first-match rule.

set -euo pipefail
shopt -s extglob

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAP="$HERE/skills-map.txt"
[[ -f "$MAP" ]] || { echo "no map at $MAP" >&2; exit 2; }

PER_FILE=0
[[ "${1:-}" == "--per-file" ]] && { PER_FILE=1; shift; }

if [[ $# -gt 0 ]]; then FILES=("$@"); else mapfile -t FILES; fi
[[ ${#FILES[@]} -gt 0 ]] || exit 0

declare -A UNION=()

matches() { # pattern-list file
  local pats="$1" f="$2" p
  IFS='|' read -ra ps <<<"$pats"
  for p in "${ps[@]}"; do
    # shellcheck disable=SC2254
    case "$f" in $p) return 0;; esac
  done
  return 1
}

for f in "${FILES[@]}"; do
  [[ -z "$f" ]] && continue
  hit=""; extra=""
  while IFS= read -r line; do
    line="${line%%#*}"; [[ -z "${line// }" ]] && continue
    pats="${line%%:*}"; skills="${line#*:}"
    pats="$(echo "$pats" | xargs)"; skills="$(echo "$skills" | xargs)"
    if [[ "$pats" == +* ]]; then
      matches "${pats#+}" "$f" && extra="$extra $skills"
    elif [[ -z "$hit" ]]; then
      matches "$pats" "$f" && hit="$skills"
    fi
  done < "$MAP"
  all="$hit $extra"
  if [[ $PER_FILE -eq 1 ]]; then
    printf '%s: %s\n' "$f" "$(echo "$all" | xargs)"
  fi
  for s in $all; do UNION[$s]=1; done
done

if [[ $PER_FILE -eq 0 ]]; then
  for s in "${!UNION[@]}"; do echo "$s"; done | sort
fi
