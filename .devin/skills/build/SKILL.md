---
name: build
description: Build an approved spec with no conversation — make every check pass, run up to three review rounds, and write a summary the user audits afterwards.
triggers:
  - user
argument-hint: "[task-name]"
---

# Build

Task: the argument given after `/build` (if there is none, the current branch name). Spec: `plans/<task>/spec.md`.

Do not ask the user anything. Every decision you make goes into a file they read afterwards: the spec, `review.md` or `summary.md`. A decision that is not written down did not happen.

## Start

1. `git switch <task>`.
2. `.devin/skills/build/spec-check.sh --start plans/<task>/spec.md`. It refuses a spec that is not approved — then stop and say so. From now on a Stop hook keeps you working while any check fails or any item is open.
3. Read `AGENTS.md` and the skills listed in step 2 of the `branch-review` skill. Read `tdd` with its `tests.md` and `mocking.md`, and `testing`, `frontend-testing` and `no-tautological-tests`. Every test you write follows these test skills; the review rounds check it against them.

## Items

Work the items in order, one at a time:

1. Make the item's check pass with the `tdd` red → green loop: the smallest failing test, the least code to pass it, repeat.
2. Search before you create any function or component. Reuse what exists.
3. Run the item's check, the typecheck and the test files you touched. Do not start the next item while one is red.
4. Commit: `feat(<task>): item <N> — <behaviour>`. Then tick the item (`[x]`), add the commit id under `commits:`, and commit the spec.

Never edit an item's check or acceptance test to make it pass. If you are sure the check or test is wrong, mark the item `[!]`, add `blocked: <why>`, and continue with the next item. Blocked is for a wrong check, never for a hard one.

## Review rounds

Run at most three rounds. Round 1 reviews the whole branch; each later round reviews only the commits since the previous round started.

1. Note `SINCE=$(git rev-parse HEAD)` for the next round.
2. Follow the `branch-review` skill with arguments `<task> <base> <since>` (`since` empty in round 1). Run its file analysis (step 3) in the `reviewer` subagent even for a small diff, so the findings never come from the context that wrote the code. The report goes to `plans/<task>/review.md`.
3. Act on every finding of the round, and record each one with a `Result:` line as that workflow describes:
   - **Fix** it: one commit per finding, `fix(<task>): review <id> — <what>`.
   - **Skip** it: write a reason the user can judge.
   - **Invalid**: write why the finding is wrong.
   - **Repeated**: a finding that comes back after it was fixed in an earlier round. Do not fix it again; leave it for the user.
4. Run `.devin/skills/build/spec-check.sh plans/<task>/spec.md` and the typecheck. A fix that breaks a check is reverted, and the finding is marked Skipped with the reason.
5. Stop the rounds when the round had no Required findings, when a finding was Repeated, or after round 3. Otherwise start the next round from step 1.

## Finish

1. Run the full test suite, the typecheck and lint once.
2. `.devin/skills/build/spec-check.sh --finish`.
3. Write `plans/<task>/summary.md` in the format below.
4. Run `.devin/skills/build/metrics.sh --record <task>`. It adds the task's results to `plans/metrics.csv`. Commit `summary.md`, `review.md` and `plans/metrics.csv`: `docs(<task>): build summary`.
5. Your final message is the verdict, one line of counts, and the path to `summary.md`. Nothing else.

## Summary format

```markdown
# <task> — build summary

Verdict: <verdict of the last review> · Rounds: <n> · Stopped because: <no Required findings | repeated finding | 3 rounds>

## Needs your decision

- <Every blocked item, open or repeated finding, and skipped finding — one line each, with its id in review.md.>

## Items

| # | Item | Result | Commits |
|---|------|--------|---------|

## Review rounds

| Round | Since | Found | Fixed | Skipped | Invalid | Repeated |
|-------|-------|-------|-------|---------|---------|----------|

## Final checks

<Each command run in Finish step 1, with the last lines of its output.>
```

Omit "Needs your decision" when there is nothing in it.
