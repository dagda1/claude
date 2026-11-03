#!/usr/bin/env bash
# review-prep.sh — does every step of a branch review that needs no judgement, and prints
# what the reviewer needs: the refs, the report path, the changed files and skills for each
# package, and the jscpd clones that touch the changed files.
#
# Usage: review-prep.sh [target] [base] [since]
#   target  branch to review (default: current branch)
#   base    branch to compare against (default: dev)
#   since   review only commits after this one (a build round)
#
# It checks out <target>. Check out ORIGINAL (printed first) when the review is done.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

ORIGINAL="$(git branch --show-current)"
TARGET="${1:-$ORIGINAL}"
BASE="${2:-dev}"
SINCE="${3:-}"

git fetch -q origin "$BASE"
git ls-remote --exit-code --heads origin "$TARGET" >/dev/null && git fetch -q origin "$TARGET"
git checkout -q "$TARGET"
MERGE_BASE="$(git merge-base "origin/$BASE" "$TARGET")"
FROM="${SINCE:-$MERGE_BASE}"

if [[ -n "$SINCE" ]]; then
  REPORT_FILE="plans/$TARGET/review.md"
else
  REPORT_FILE="${TMPDIR:-/tmp}/branch-review-$(echo "$TARGET" | tr '/' '-').md"
fi

CHANGED="$(git diff --name-only "$FROM" "$TARGET" -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.css' '*.json' |
  grep -v node_modules | grep -v '\.d\.ts$' || true)"

cat <<EOF
ORIGINAL=$ORIGINAL
TARGET=$TARGET
BASE=$BASE
MERGE_BASE=$MERGE_BASE
FROM=$FROM
REPORT_FILE=$REPORT_FILE
EOF

[[ -n "$CHANGED" ]] || { echo; echo "No changed files."; exit 0; }

# A package is the first two path segments under apps/ or packages/; anything else is root.
package_of() {
  case "$1" in
    apps/*/* | packages/*/*) echo "$1" | cut -d/ -f1-2 ;;
    *) echo "root" ;;
  esac
}

for pkg in $(while read -r f; do package_of "$f"; done <<<"$CHANGED" | sort -u); do
  files=()
  while read -r f; do [[ "$(package_of "$f")" == "$pkg" ]] && files+=("$f"); done <<<"$CHANGED"
  echo
  echo "## Package $pkg"
  echo
  echo "Files:"
  printf -- '- %s\n' "${files[@]}"
  echo
  echo "Skills:"
  "$HERE/skills-for.sh" "$FROM" "$TARGET" "${files[@]}" | sed 's/^/- /'
done

echo
echo "## jscpd"
echo
JSCPD="node_modules/.bin/jscpd"
if [[ ! -x "$JSCPD" ]]; then
  echo "jscpd not installed: $JSCPD"
  exit 0
fi
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
"$JSCPD" ./apps ./packages --baseline-from-ref "$MERGE_BASE" \
  --absolute --reporters json --output "$OUT" --silent --no-tips >/dev/null 2>&1 || true

# Keep only clones with a half in a changed file. Print both halves and the fragment.
CHANGED_ABS="$(sed "s|^|$ROOT/|" <<<"$CHANGED")" node -e '
  const fs = require("fs");
  const file = process.argv[1] + "/jscpd-report.json";
  if (!fs.existsSync(file)) { console.log("jscpd wrote no report."); process.exit(0); }
  const changed = new Set(process.env.CHANGED_ABS.split("\n"));
  const all = JSON.parse(fs.readFileSync(file, "utf8")).duplicates || [];
  const kept = all.filter(d => changed.has(d.firstFile.name) || changed.has(d.secondFile.name));
  const rel = p => p.replace(process.argv[2] + "/", "");
  const half = f => `${rel(f.name)}:${f.start}-${f.end}`;
  console.log(`jscpd: ${all.length} clones reported, ${kept.length} touch changed files.`);
  kept.forEach((d, i) => {
    console.log(`\n### Clone ${i + 1}: ${half(d.firstFile)} and ${half(d.secondFile)}\n`);
    console.log("```" + (d.format || ""));
    console.log(d.fragment.trimEnd());
    console.log("```");
  });
' "$OUT" "$ROOT"
