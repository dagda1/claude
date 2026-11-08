#!/usr/bin/env bash
# spec-check.sh — runs the check of every item in a spec and reports what is not done.
# The spec, not the model, decides when the build is finished.
#
# Usage:
#   spec-check.sh <spec.md>          run every check; exit 1 if a check fails or an item is open
#   spec-check.sh --start <spec.md>  mark a build active (spec must be approved)
#   spec-check.sh --hook             Stop hook: prints {"decision": "block"} while an item is open; runs no checks
#   spec-check.sh --finish           end the build and uncommit its commits; refuses while it is not done,
#                                    without review.md, grade.md or summary.md
#   spec-check.sh --uncommit         end the build and uncommit its commits, done or not
#
# Item format (see the spec skill). spec.md, beside it llm.md:
#   spec.md                        llm.md
#   - [ ] 1. <behaviour>  open     - 1. <detail>
#   - [x] 1. <behaviour>  done       - check: `<command>`   its check must pass
#   - [!] 1. <behaviour>  blocked    - visual: <story>      instead of check: — the user approves it in Storybook
#     - blocked: <why>    needed under a [!] item
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
RE_VISUAL='visual: (.+)'

llm_of() { echo "$(dirname "$1")/llm.md"; }

# The lines under item $2 in the `## Items` section of llm.md $1.
llm_item() {
  awk -v n="$2" '
    /^## / { items = ($0 == "## Items"); cur = ""; next }
    items && /^- [0-9]+\./ { cur = $2; sub(/\..*/, "", cur); next }
    items && cur == n
  ' "$1"
}

check_spec() {
  local spec="$1" failed=0 item="" state="" has_blocked=0 llm

  [[ -f "$spec" ]] || { echo "spec not found: $spec"; return 1; }
  llm="$(llm_of "$spec")"
  [[ -f "$llm" ]] || { echo "llm.md not found: $llm"; return 1; }

  end_item() {
    [[ -z "$item" ]] && return
    local has_check=0 visual="" line cmd
    while IFS= read -r line; do
      if [[ "$line" =~ $RE_VISUAL ]]; then
        visual="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ $RE_CHECK ]]; then
        has_check=1
        cmd="${BASH_REMATCH[1]}"
        if (cd "$ROOT" && bash -c "$cmd") </dev/null >"$LOG" 2>&1; then
          echo "item $item: PASS"
        elif [[ "$state" == "!" ]]; then
          echo "item $item: BLOCKED (check fails, left for the user)"
        else
          echo "item $item: FAIL — $cmd"
          tail -n 20 "$LOG" | sed 's/^/    /'
          failed=1
        fi
      fi
    done < <(llm_item "$llm" "$item")
    if [[ $has_check -eq 1 && -n "$visual" ]]; then
      echo "item $item: CHECK AND VISUAL — an item has one or the other"
      failed=1
    elif [[ -n "$visual" ]]; then
      echo "item $item: VISUAL — approve in Storybook: $visual"
    elif [[ $has_check -eq 0 ]]; then
      echo "item $item: NO CHECK — every item needs a check: or visual: line in llm.md"
      failed=1
    fi
    if [[ "$state" == "!" && $has_blocked -eq 0 ]]; then
      echo "item $item: BLOCKED WITHOUT REASON — add a blocked: line"
      failed=1
    fi
  }

  while IFS= read -r line; do
    if [[ "$line" =~ $RE_ITEM ]]; then
      local next_state="${BASH_REMATCH[1]}" next_item="${BASH_REMATCH[2]}"
      end_item
      state="$next_state"
      item="$next_item"
      has_blocked=0
      if [[ "$state" == " " ]]; then
        echo "item $item: OPEN"
        failed=1
      fi
    elif [[ -n "$item" && "$line" =~ $RE_BLOCKED ]]; then
      has_blocked=1
    fi
  done <"$spec"
  end_item

  [[ -n "$item" ]] || { echo "no items found in $spec"; return 1; }
  return $failed
}

open_items() {
  awk '
    function close_item() { if (state == "!" && !blocked) print "item " id " BLOCKED WITHOUT REASON" }
    /^- \[[ xX!]\] [0-9]+\./ { close_item(); state = substr($0, 4, 1); id = substr($0, 7); sub(/\..*/, "", id); blocked = 0; if (state == " ") print "item " id " OPEN"; next }
    id != "" && /blocked: .+/ { blocked = 1 }
    END { close_item() }
  ' "$1"
}

unresolved_findings() {
  awk '
    /^### [0-9]+\.[0-9]+/ { if (id != "") print id; id = $2; next }
    id != "" && NF { if ($0 !~ /^Result: /) print id; id = "" }
    END { if (id != "") print id }
  ' "$1"
}

# Refuses unless grade.md $1 ends at satisfied or failed, or has had 3 rounds.
grade_done() {
  local rounds last
  rounds=$(grep -c '^Verdict: ' "$1")
  last=$(grep '^Verdict: ' "$1" | tail -n 1 | awk '{ print $2 }')
  [[ "$last" == "satisfied" || "$last" == "failed" ]] || ((rounds >= 3))
}

end_build() {
  git reset --soft "$(cat "$START")" || { echo "reset to $(cat "$START") failed — build left active" >&2; exit 1; }
  git reset -q -- "$(dirname "$(cat "$MARKER")")"
  echo "- $(date '+%F %H:%M') build ended ($1): changes uncommitted from $(cat "$START")" >>"$(dirname "$(cat "$MARKER")")/log.md"
  rm -f "$MARKER" "$BLOCKS" "$START"
}

case "${1:-}" in
  --start)
    [[ -f "${2:?usage: spec-check.sh --start <spec.md>}" ]] || { echo "no spec at $2 — run /spec first" >&2; exit 1; }
    spec="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
    grep -q '^Status: approved' "$spec" || { printf 'spec is not approved: %s\nRead it, then reply "approved" in the /spec session, or change "Status: draft" to "Status: approved" yourself, and run /build again.\n' "$spec" >&2; exit 1; }
    [[ -f "$(llm_of "$spec")" ]] || { echo "no llm.md beside $spec — run /spec first" >&2; exit 1; }
    heavy="$(grep -nE 'check: `.*(pnpm (-r )?(build|test|lint)\b|turbo run)' "$(llm_of "$spec")" | grep -v -- '--filter')"
    [[ -z "$heavy" ]] || { printf 'full-repo build/test/lint in a check; CI runs those. Use pnpm --filter <package>:\n%s\n' "$heavy" >&2; exit 1; }
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
    out="$(open_items "$spec")"
    if [[ -n "$out" ]]; then
      blocks=$(($(cat "$BLOCKS" 2>/dev/null || echo 0) + 1))
      ((blocks > MAX_BLOCKS + 1)) && exit 0
      echo "$blocks" >"$BLOCKS"
      if ((blocks > MAX_BLOCKS)); then
        echo "- $(date '+%F %H:%M') stop hook gave up after $MAX_BLOCKS blocks, build still active — run spec-check.sh --uncommit" >>"$(dirname "$spec")/log.md"
        exit 0
      fi
      echo "- $(date '+%F %H:%M') stop blocked ($blocks of $MAX_BLOCKS): $(echo "$out" | paste -sd, -)" >>"$(dirname "$spec")/log.md"
      reason="$(printf 'The build is not done (stop %s of %s). Keep working until every item is done:\n%s' "$blocks" "$MAX_BLOCKS" "$out" |
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
    grade="$(dirname "$spec")/grade.md"
    [[ -f "$grade" ]] || { echo "no grade: $grade — not finishing" >&2; exit 1; }
    grade_done "$grade" || { echo "grade.md ends at needs_revision before round 3 — not finishing" >&2; exit 1; }
    summary="$(dirname "$spec")/summary.md"
    [[ -f "$summary" ]] || { echo "no summary: $summary — not finishing" >&2; exit 1; }
    long="$(awk '/^- / && NF > 26 { print FILENAME ":" FNR }' "$summary")"
    [[ -z "$long" ]] || { echo "bullets over 25 words: $long — not finishing" >&2; exit 1; }
    end_build finished
    echo "build finished: $spec"
    ;;
  --uncommit)
    [[ -f "$MARKER" ]] || { echo "no active build"; exit 0; }
    end_build uncommitted
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