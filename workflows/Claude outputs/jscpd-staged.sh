#!/usr/bin/env bash
# jscpd wrapper for lint-staged: strips import/export-from lines before
# detection so identical import blocks never count as duplication, then
# runs jscpd on the stripped copies. Line numbers are preserved because
# stripped lines are replaced with unique no-op comments, not deleted.
set -euo pipefail
[ $# -gt 0 ] || exit 0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
i=0
for f in "$@"; do
  rel="${f#"$PWD"/}"
  dest="$TMP/$rel"; mkdir -p "$(dirname "$dest")"
  # Replace import lines with a per-line unique comment so they can never
  # match each other, while keeping every other line at its real number.
  awk -v n=$((i*100000)) '
    /^[[:space:]]*import[[:space:]]/ || /^[[:space:]]*export[[:space:]]+\*[[:space:]]+from/ \
      { n++; printf("// __stripped_%d__\n", n); next }
    { print }' "$f" > "$dest"
  i=$((i+1))
done
cd "$TMP"
exec "$OLDPWD/node_modules/.bin/jscpd" --exitCode 1 --config "$OLDPWD/.jscpd.json" .
