#!/usr/bin/env bash
# lint-edit.sh — hook that runs ESLint on a file straight after the agent edits it and hands
# any errors back to the agent, so they are fixed before the next edit, not in a review round.
#
# Usage (PostToolUse on the edit and write tools, event JSON on stdin):
#   .claude/settings.json   matcher "Edit|Write|MultiEdit"
#   .devin/hooks.v1.json    matcher "edit|write"
#
# Says nothing when the file is clean, is not JS/TS, or the project has no ESLint.
# Reports errors only (--quiet), at most 40 lines, so a clean edit costs no tokens.
set -uo pipefail

ROOT="${DEVIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
if [[ -z "$ROOT" ]] || ! cd "$ROOT"; then
  cat >/dev/null
  exit 0
fi

file="$(node -e '
let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  try { console.log(JSON.parse(s).tool_input?.file_path ?? ""); } catch {}
});
')"
[[ "$file" =~ \.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$ ]] || exit 0
[[ "$file" == /* ]] || file="$ROOT/$file"
[[ -f "$file" && "$file" != */node_modules/* ]] || exit 0

# Walk up from the file: the nearest eslint binary, and the nearest folder with an ESLint
# config, which is where eslint runs so a package's own config applies in a monorepo.
dir="$(dirname "$file")"
bin=""
cfg=""
while :; do
  [[ -z "$bin" && -x "$dir/node_modules/.bin/eslint" ]] && bin="$dir/node_modules/.bin/eslint"
  if [[ -z "$cfg" ]]; then
    for c in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts \
      eslint.config.cts .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml; do
      [[ -f "$dir/$c" ]] && cfg="$dir" && break
    done
  fi
  [[ "$dir" == "$ROOT" || "$dir" == "/" ]] && break
  dir="$(dirname "$dir")"
done
[[ -n "$bin" ]] || exit 0

out="$(cd "${cfg:-$ROOT}" && "$bin" --quiet "$file" 2>&1)"
code=$?
[[ $code -eq 0 ]] && exit 0
if [[ $code -ne 1 ]]; then
  # ESLint itself failed (bad config, crash). Tell the user, not the agent.
  echo "lint-edit.sh: eslint could not run on ${file#"$ROOT"/}" >&2
  exit 1
fi

MSG="ESLint errors in ${file#"$ROOT"/}. Fix them before the next edit.
$(echo "$out" | head -40)" node -e '
const m = process.env.MSG;
console.log(JSON.stringify(
  process.env.DEVIN_PROJECT_DIR
    ? { hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: m } }
    : { decision: "block", reason: m }
));
'
exit 0
