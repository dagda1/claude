#!/usr/bin/env bash
# review-bundle.sh — writes everything a reviewer needs (the skills that apply and the numbered
# diff of every file) into chunk files small enough for one read call each. One batch unless the
# diff is too large for one reviewer; then whole packages are grouped into batches.
# Usage: review-bundle.sh <from> <target> <out-prefix> <file>...
set -euo pipefail

(($# >= 4)) || { echo "usage: review-bundle.sh <from> <target> <out-prefix> <file>..." >&2; exit 64; }
HERE="$(cd "$(dirname "$0")" && pwd)"
FROM="$1" TARGET="$2" PREFIX="$3"
shift 3

MAX_BATCH_BYTES=500000
CHUNK_CHARS=18000

package_of() {
  case "$1" in
    apps/*/* | packages/*/*) echo "$1" | cut -d/ -f1-2 ;;
    *) echo "root" ;;
  esac
}

batches=()
current=()
current_bytes=0
for pkg in $(for f in "$@"; do package_of "$f"; done | sort -u); do
  files=()
  for f in "$@"; do [[ "$(package_of "$f")" == "$pkg" ]] && files+=("$f"); done
  bytes=$("$HERE/numbered-diff.sh" "$FROM" "$TARGET" "${files[@]}" | wc -c)
  if ((${#current[@]} && current_bytes + bytes > MAX_BATCH_BYTES)); then
    batches+=("${current[*]}")
    current=()
    current_bytes=0
  fi
  current+=("${files[@]}")
  current_bytes=$((current_bytes + bytes))
done
batches+=("${current[*]}")

rm -f "$PREFIX"-batch*-chunk*.md
n=0
for batch in "${batches[@]}"; do
  n=$((n + 1))
  read -ra files <<<"$batch"
  skills="$("$HERE/skills-for.sh" "$FROM" "$TARGET" "${files[@]}" | grep -v '^AGENTS.md$')"
  {
    echo "# Review input, batch $n"
    echo
    echo "## Files"
    printf -- '- %s\n' "${files[@]}"
    while read -r skill; do
      echo
      echo "## Skill: $skill"
      echo
      cat "$skill"
    done <<<"$skills"
    echo
    echo "## Numbered diff (from $FROM to $TARGET)"
    echo
    "$HERE/numbered-diff.sh" "$FROM" "$TARGET" "${files[@]}"
  } | awk -v max="$CHUNK_CHARS" -v out="$PREFIX-batch$n-chunk" '
    BEGIN { part = 1; size = 0; file = sprintf("%s%02d.md", out, part) }
    size > 0 && size + length($0) + 1 > max { close(file); part++; size = 0; file = sprintf("%s%02d.md", out, part) }
    { print > file; size += length($0) + 1 }
  '
  echo "## Batch $n"
  echo
  echo "Files: ${#files[@]}"
  echo
  echo "Skills:"
  sed 's/^/- /' <<<"$skills"
  echo
  echo "Read:"
  ls "$PREFIX-batch$n"-chunk*.md | sed 's/^/- /'
  echo
done
