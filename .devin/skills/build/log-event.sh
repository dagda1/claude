#!/usr/bin/env bash
# log-event.sh — hook that appends to plans/<task>/log.md, so the record of a task does not
# come from the agent. The task is the current branch; nothing is logged without its folder.
#
# Usage (from .devin/hooks.v1.json, event JSON on stdin):
#   log-event.sh prompt   UserPromptSubmit: every message the user sends
#   log-event.sh tool     PostToolUse: only tool calls that failed
set -uo pipefail

cd "${DEVIN_PROJECT_DIR:-.}" || exit 0
task="$(git branch --show-current)"
if [[ -z "$task" || "$task" == dev || ! -d "plans/$task" ]]; then
  cat >/dev/null
  exit 0
fi

line="$(node -e '
let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  const e = JSON.parse(s);
  const flat = (t) => String(t ?? "").replace(/\s+/g, " ").trim().slice(0, 300);
  if (process.argv[1] === "prompt") console.log(`user: ${flat(e.prompt)}`);
  if (process.argv[1] === "tool" && e.tool_response?.success === false) {
    const what = e.tool_input?.command ?? e.tool_input?.file_path ?? "";
    console.log(`failed ${e.tool_name}: ${flat(what)} | ${flat(e.tool_response.error)}`);
  }
});
' "$1")"

[[ -n "$line" ]] && echo "- $(date '+%F %H:%M') $line" >>"plans/$task/log.md"
exit 0
