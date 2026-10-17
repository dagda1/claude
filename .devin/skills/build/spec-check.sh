#!/usr/bin/env bash
# spec-check.sh — runs the check of every item in a spec and reports what is not done.
# The spec, not the model, decides when the build is finished.
#
# Usage:
#   spec-check.sh <spec.md>          run every check; exit 1 if a check fails or an item is open
#   spec-check.sh --start <spec.md>  mark a build active (spec must be approved)
#   spec-check.sh --hook             Stop hook: prints {"decision": "block"} while the active build is not done
#   spec-check.sh --finish           end the build and uncommit its commits; refuses while it is not done
#   spec-check.sh --uncommit         end the build and uncommit its commits, done or not
#
# Spec item format (see the spec skill):
#   - [ ] 1. <behaviour>       open
#   - [x] 1. <behaviour>       done — its check must pass
#   - [!] 1. <behaviour>       blocked — needs a `blocked:` line; left for the user
#     - check: `<command>`
#
# The active build and its starting commit are recorded in .git/, so they are never committed.
# Ending a build resets the branch to the starting commit with --soft: every change the
# build made stays in the working tree, staged, for the user to review.
set -uo pipefail

PROJECT_DIR="${DEVIN_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
[[ "${1:-}" == "--hook" && -n "$PROJECT_DIR" ]] && cd "$PROJECT_DIR"
ROOT="$(git rev-parse --show-toplevel)"
MARKER="$(git rev-parse --absolute-git-dir)/harness-build"
BLOCKS="$MARKER.blocks"
START="$MARKER.start"
MAX_BLOCKS=5
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

RE_ITEM='^- \[([ xX!])\] ([0-9]+)\.'
RE_CHECK='check: `(.*)`'
RE_BLOCKED='blocked: .+'

check_spec() {
  local spec="$1" failed=0 item="" state="" has_check=0 has_blocked=0

  [[ -f "$spec" ]] || { echo "spec not found: $spec"; return 1; }

  end_item() {
    [[ -z "$item" ]] && return
    if [[ $has_check -eq 0 ]]; then
      echo "item $item: NO CHECK — every item needs a check: line"
      failed=1
    fi
    if [[ "$state" == "!" && $has_blocked -eq 0 ]]; then
      echo "item $item: BLOCKED WITHOUT REASON — add a blocked: line"
      failed=1
    fi
  }

  while IFS= read -r line; do
    if [[ "$line" =~ $RE_ITEM ]]; then
      end_item
      state="${BASH_REMATCH[1]}"
      item="${BASH_REMATCH[2]}"
      has_check=0
      has_blocked=0
      if [[ "$state" == " " ]]; then
        echo "item $item: OPEN"
        failed=1
      fi
    elif [[ -n "$item" && "$line" =~ $RE_BLOCKED ]]; then
      has_blocked=1
    elif [[ -n "$item" && "$line" =~ $RE_CHECK ]]; then
      has_check=1
      local cmd="${BASH_REMATCH[1]}"
      if (cd "$ROOT" && bash -c "$cmd") >"$LOG" 2>&1; then
        echo "item $item: PASS"
      elif [[ "$state" == "!" ]]; then
        echo "item $item: BLOCKED (check fails, left for the user)"
      else
        echo "item $item: FAIL — $cmd"
        tail -n 20 "$LOG" | sed 's/^/    /'
        failed=1
      fi
    fi
  done <"$spec"
  end_item

  [[ -n "$item" ]] || { echo "no items found in $spec"; return 1; }
  return $failed
}

unresolved_findings() {
  awk '
    /^### [0-9]+\.[0-9]+/ { if (id != "") print id; id = $2; next }
    id != "" && NF { if ($0 !~ /^Result: /) print id; id = "" }
    END { if (id != "") print id }
  ' "$1"
}

end_build() {
  git reset --soft "$(cat "$START")" || { echo "reset to $(cat "$START") failed — build left active" >&2; exit 1; }
  rm -f "$MARKER" "$BLOCKS" "$START"
}

case "${1:-}" in
  --start)
    [[ -f "${2:?usage: spec-check.sh --start <spec.md>}" ]] || { echo "no spec at $2 — run /spec first" >&2; exit 1; }
    spec="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
    grep -q '^Status: approved' "$spec" || { echo "spec is not approved: $spec" >&2; exit 1; }
    if [[ -f "$MARKER" && "$(cat "$MARKER")" != "$spec" ]]; then
      echo "an unfinished build for $(cat "$MARKER") is still active — run spec-check.sh --uncommit first" >&2
      exit 1
    fi
    [[ -f "$MARKER" && -f "$START" ]] || git rev-parse HEAD >"$START"
    echo "$spec" >"$MARKER"
    rm -f "$BLOCKS"
    echo "build active: $spec, starting from $(cat "$START")"
    ;;
  --hook)
    cat >/dev/null
    [[ -f "$MARKER" ]] || exit 0
    spec="$(cat "$MARKER")"
    if ! out="$(check_spec "$spec")"; then
      blocks=$(($(cat "$BLOCKS" 2>/dev/null || echo 0) + 1))
      ((blocks > MAX_BLOCKS)) && exit 0
      echo "$blocks" >"$BLOCKS"
      echo "- $(date '+%F %H:%M') stop blocked ($blocks of $MAX_BLOCKS): $(echo "$out" | grep -E 'OPEN|FAIL' | cut -d: -f1 | paste -sd, -)" >>"$(dirname "$spec")/log.md"
      reason="$(printf 'The build is not done (stop %s of %s). Keep working until every check passes:\n%s' "$blocks" "$MAX_BLOCKS" "$out" |
        awk '{ gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, " "); printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')"
      printf '{"decision": "block", "reason": "%s"}\n' "$reason"
    fi
    ;;
  --finish)
    [[ -f "$MARKER" ]] || { echo "no active build"; exit 0; }
    spec="$(cat "$MARKER")"
    check_spec "$spec" || { echo "build not done — not finishing" >&2; exit 1; }
    review="$(dirname "$spec")/review.md"
    [[ -f "$review" ]] || { echo "no review: $review — not finishing" >&2; exit 1; }
    unresolved="$(unresolved_findings "$review")"
    [[ -z "$unresolved" ]] || { echo "findings without a Result: line in $review: $(echo $unresolved) — not finishing" >&2; exit 1; }
    end_build
    echo "build finished: $spec"
    ;;
  --uncommit)
    [[ -f "$MARKER" ]] || { echo "no active build"; exit 0; }
    end_build
    echo "build ended; its changes are uncommitted in the working tree"
    ;;
  "" | -*)
    echo "usage: spec-check.sh <spec.md> | --start <spec.md> | --hook | --finish | --uncommit" >&2
    exit 64
    ;;
  *)
    check_spec "$1"
    ;;
esac