---
name: spec
description: Agree a spec for a piece of work and write its failing acceptance tests, ready for /build. This is the only conversation before the build. Use for /spec.
disable-model-invocation: true
argument-hint: "[task-name]"
---

# Spec

Task name: `$ARGUMENTS`. The task name is also the branch name and the folder name. If it is empty, ask for it.

Everything for the task lives in `plans/<task>/`. This skill writes `spec.md` and the acceptance tests. `/build` does the rest in a new session, with no conversation, so the spec must hold everything the build needs.

## Steps

1. **Branch.** `git switch <task>` if the branch exists, otherwise `git switch -c <task>`. `mkdir -p plans/<task>`.

2. **Interview.** Follow the `grilling` skill until its frontier is empty. Find facts yourself; put only decisions to the user. The tree must settle:
   - the behaviour, item by item,
   - what is out of scope,
   - the seams each item is tested at (the `tdd` skill: test only at agreed seams),
   - the one command that proves each item done.

3. **Write `plans/<task>/spec.md`** in the format below. Each item has exactly one `check:` command. An item with no check is not ready — go back to the interview, do not invent one.

4. **Write the acceptance tests.** One test per item, at the agreed seam. This is the outer loop that defines done; the red → green loop for each item happens in `/build`. Before you write a test, read the test skills:
   - `tdd` with its `tests.md` and `mocking.md`,
   - the skills `.claude/skills/skills-for-files.sh <test files>` names for the test files (for example `no-tautological-tests`, `frontend-testing`, `code-test-colocation`).

   Expected values come from the spec, never from the code.

5. **Review the tests.** Give the test files and the same test skills to the `reviewer` agent, with the diff from the branch's merge base. It reviews against the skills only — it did not write the tests. Write its findings to `plans/<task>/test-review.md` and act on each one with a `Result:` line (Fixed with the commit id, Skipped with a reason, or Invalid with why), as in `.claude/commands/branch-review.md`. Repeat the review on the fixes until it reports no Required findings, at most three rounds.

6. **Prove they fail.** Run `.claude/scripts/spec-check.sh plans/<task>/spec.md`. Every item must report `FAIL` for the right reason (the behaviour is missing, not a typo or a missing import). A check that passes now proves nothing — fix it.

7. **Commit** the spec, the tests and `test-review.md`: `spec(<task>): <goal>`.

8. **Stop for approval.** Give the user the spec path, the list of test files and the path to `test-review.md`, nothing else. When they approve, change `Status: draft` to `Status: approved`, commit, and tell them to start a new session with `/build <task>`. If they want changes, make them and repeat from step 5.

## Spec format

```markdown
# <task>

Status: draft
Branch: <task>

## Goal

<One or two sentences: what changes for the user of the code.>

## Out of scope

- <What this task does not do.>

## Items

- [ ] 1. <One behaviour, one sentence.>
  - check: `<command that fails now and passes when the item is done>`
  - test: `<path to the acceptance test>`
  - commits:
- [ ] 2. ...
```

A check is one shell command run from the repo root, for example `pnpm --filter @app/frontend exec vitest run src/pages/Results/Results.test.tsx`. Keep it to the one test file, so it is fast.

`/build` ticks items (`[x]`), adds commit ids under `commits:`, and may mark an item blocked (`[!]` with a `blocked:` line) when the check or test itself is wrong. Nothing else in the spec changes after approval.
