#!/usr/bin/env bash
# skills-for.test.sh — tests skills-for.sh against the real skill-globs.txt.
# Usage: skills-for.test.sh    (exit 0 when every check passes)
# It builds a throwaway git repo with two commits and checks which skills each file loads.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/skills-for.sh"
MAP="$HERE/skill-globs.txt"
SKILLS_DIR="$(dirname "$HERE")"

fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# has <name> <output> <skill>: the output lists the skill.
has() {
  if grep -qx ".claude/skills/$3/SKILL.md" <<<"$2"; then pass "$1"; else fail "$1: no $3"; fi
}
# lacks <name> <output> <skill>: the output does not list the skill.
lacks() {
  if grep -qx ".claude/skills/$3/SKILL.md" <<<"$2"; then fail "$1: has $3"; else pass "$1"; fi
}

REPO="$(mktemp -d)"
trap 'rm -rf "$REPO"' EXIT
cd "$REPO" || exit 1
git init -q
git config user.email test@example.com
git config user.name test
mkdir -p src deploy

# Commit 1: Old.tsx already imports react-query.
printf '%s\n' "import { useQuery } from '@tanstack/react-query';" 'export const Old = () => null;' >src/Old.tsx
git add -A && git commit -qm one
FROM="$(git rev-parse HEAD)"

# Commit 2: Old.tsx gets a line with no import; the other files are new.
echo 'export const more = 1;' >>src/Old.tsx
echo 'export const Plain = () => null;' >src/Plain.tsx
printf '%s\n' "import { useQuery } from '@tanstack/react-query';" 'export const New = () => null;' >src/New.tsx
echo 'export const add = (a: number, b: number) => a + b;' >src/util.ts
echo "it('adds', () => {});" >src/util.test.ts
echo 'export const Default = {};' >src/Plain.stories.tsx
echo 'export const Signup = () => <TextField value="" helperText="x" />;' >src/Signup.tsx
echo 'export class AppStack {}' >deploy/app.stack.ts
echo '# notes' >notes.md
git add -A && git commit -qm two
TARGET="$(git rev-parse HEAD)"

run() { "$SCRIPT" "$FROM" "$TARGET" "$@"; }

# Every file loads AGENTS.md first, then the review rules.
out="$(run notes.md)"
if [[ "$(head -1 <<<"$out")" == "AGENTS.md" ]]; then pass "AGENTS.md is first"; else fail "AGENTS.md is first"; fi
has "any file loads review-secret-scanning" "$out" review-secret-scanning
if [[ "$(wc -l <<<"$out" | tr -d ' ')" == 2 ]]; then pass "a markdown file loads nothing else"; else fail "a markdown file loads nothing else: $out"; fi

# A test file loads the test skills, not the plain TS skills.
out="$(run src/util.test.ts)"
has "test file loads frontend-testing" "$out" frontend-testing
has "test file loads no-tautological-tests" "$out" no-tautological-tests
has "test file loads code-test-colocation" "$out" code-test-colocation
lacks "test file skips code-error-handling" "$out" code-error-handling

# A plain TS file loads the plain TS skills, not the test or component skills.
out="$(run src/util.ts)"
has "TS file loads code-error-handling" "$out" code-error-handling
has "TS file loads code-trust-the-types" "$out" code-trust-the-types
lacks "TS file skips frontend-testing" "$out" frontend-testing
lacks "TS file skips frontend-react-typescript" "$out" frontend-react-typescript

# A component loads the component skills; a regex rule needs a matching added line.
out="$(run src/Plain.tsx)"
has "component loads frontend-react-typescript" "$out" frontend-react-typescript
has "component loads frontend-no-boolean-params" "$out" frontend-no-boolean-params
lacks "component with no import skips frontend-react-query" "$out" frontend-react-query
lacks "component with no form field skips frontend-prefer-rjsf-forms" "$out" frontend-prefer-rjsf-forms
lacks "component skips frontend-storybook" "$out" frontend-storybook

out="$(run src/Signup.tsx)"
has "added form field loads frontend-prefer-rjsf-forms" "$out" frontend-prefer-rjsf-forms

out="$(run src/New.tsx)"
has "added import loads frontend-react-query" "$out" frontend-react-query
has "added import loads frontend-api-calls" "$out" frontend-api-calls

out="$(run src/Old.tsx)"
lacks "import that the diff does not add skips frontend-react-query" "$out" frontend-react-query

# A story loads the Storybook skill, not the component skills.
out="$(run src/Plain.stories.tsx)"
has "story loads frontend-storybook" "$out" frontend-storybook
lacks "story skips frontend-react-typescript" "$out" frontend-react-typescript

# A path rule loads the CDK skills.
out="$(run deploy/app.stack.ts)"
has "stack file loads cdk-construct-conventions" "$out" cdk-construct-conventions
has "stack file loads cdk-iam-least-privilege" "$out" cdk-iam-least-privilege

# Several files: each skill is listed once.
out="$(run src/util.ts src/util.test.ts src/Plain.tsx)"
if [[ -z "$(sort <<<"$out" | uniq -d)" ]]; then pass "no skill is listed twice"; else fail "no skill is listed twice"; fi

# File names on stdin give the same result as arguments.
if [[ "$(printf '%s\n' src/util.ts src/New.tsx | run)" == "$(run src/util.ts src/New.tsx)" ]]; then
  pass "stdin matches arguments"
else
  fail "stdin matches arguments"
fi

# Bad input.
"$SCRIPT" "$FROM" >/dev/null 2>&1
if [[ $? == 64 ]]; then pass "one argument exits 64"; else fail "one argument exits 64"; fi
"$SCRIPT" "$FROM" "$TARGET" </dev/null >/dev/null 2>&1
if [[ $? == 1 ]]; then pass "no files exits 1"; else fail "no files exits 1"; fi

# Every skill the map names exists.
while read -r glob skill _; do
  [[ -z "$glob" || "$glob" == \#* ]] && continue
  [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]] || fail "map names a missing skill: $skill"
done <"$MAP"
pass "map checked for missing skills"

echo
if ((fails)); then echo "$fails failed"; exit 1; fi
echo "all passed"
