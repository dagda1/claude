#!/usr/bin/env bash
# numbered-diff.sh — prints a diff with 20 lines of context, each line prefixed with its
# line number in <target>. Removed lines get no number. Use the numbers to cite lines
# without reading the whole file.
# Usage: numbered-diff.sh <from> <target> <file>...
set -euo pipefail
(($# >= 3)) || { echo "usage: numbered-diff.sh <from> <target> <file>..." >&2; exit 64; }
FROM="$1" TARGET="$2"
shift 2

git diff -U20 "$FROM" "$TARGET" -- "$@" | awk '
  /^diff --git/ { hdr = 1; print; next }
  /^@@/ { hdr = 0; match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1); print; next }
  hdr { print; next }
  /^-/ { printf "      %s\n", $0; next }
  /^\\/ { print; next }
  { printf "%5d %s\n", n, $0; n++ }
'
