#!/usr/bin/env bash
# check-quotes.sh — checks that each finding quotes the line it cites.
# Input on stdin, one finding per line: <file><TAB><line><TAB><quoted text>
# Output, one per finding:
#   OK      <file>:<line>
#   MOVED   <file>:<line> -> <file>:<actual line>   (correct the reference)
#   MISSING <file>:<line>                           (drop the finding)
# Exits 1 when any quote is MOVED or MISSING.
set -uo pipefail

status=0
while IFS=$'\t' read -r file line quote; do
  [[ -z "$file" ]] && continue
  hits="$(grep -nF -- "$quote" "$file" 2>/dev/null | cut -d: -f1)"
  if grep -qx -- "$line" <<<"$hits"; then
    echo "OK      $file:$line"
  elif [[ -n "$hits" ]]; then
    echo "MOVED   $file:$line -> $file:$(head -n1 <<<"$hits")"
    status=1
  else
    echo "MISSING $file:$line"
    status=1
  fi
done
exit $status
