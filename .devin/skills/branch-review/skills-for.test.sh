#!/usr/bin/env bash
# skills-for.sh — prints the skills that apply to a set of changed files, one per line.
# Usage: skills-for.sh <from> <target> <file>...    (or pipe file names on stdin)
# Rules come from skill-globs.txt next to this script. AGENTS.md always applies.
# A rule with a regex matches only when a line that `git diff <from> <target>` adds to the
# file matches the regex.
set -euo pipefail
shopt -s extglob

MAP="$(dirname "$0")/skill-globs.txt"
[[ -f "$MAP" ]] || { echo "no glob map: $MAP" >&2; exit 1; }

(($# >= 2)) || { echo "usage: skills-for.sh <from> <target> <file>..." >&2; exit 64; }
FROM="$1" TARGET="$2"
shift 2
files=("$@")
if ((!$#)); then while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done; fi
((${#files[@]})) || { echo "no files given" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The lines the diff adds to file number $1, cached so each file is diffed once.
added() {
  local out="$TMP/$1"
  [[ -f "$out" ]] || git diff "$FROM" "$TARGET" -- "${files[$1]}" | grep '^+[^+]' >"$out" || true
  echo "$out"
}

{
  echo "AGENTS.md"
  while read -r glob skill regex; do
    [[ -z "$glob" || "$glob" == \#* ]] && continue
    for i in "${!files[@]}"; do
      # shellcheck disable=SC2053 # $glob is a pattern on purpose
      [[ "${files[$i]}" == $glob ]] || continue
      if [[ -n "$regex" ]]; then
        grep -qE -- "$regex" "$(added "$i")" || continue
      fi
      echo ".devin/skills/$skill/SKILL.md"
      break
    done
  done <"$MAP"
} | awk '!seen[$0]++'
