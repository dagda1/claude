---
name: spec
description: Agree a spec for a piece of work and write its failing acceptance tests, ready for /build. This is the only conversation before the build.
triggers:
  - user
---

# Spec

The task is the current branch (`git branch --show-current`). It is also the folder name. If it is `dev`, stop and say so.

Everything for the task lives in `plans/<task>/`. This skill writes `spec.md` and the acceptance tests. `/build` does the rest in a new session, with no conversation, so the spec must hold everything the build needs.

## Steps

1. **Folder.** `mkdir -p plans/<task>`.

2. **Ask what the task is.** Ask the user to describe the task. Search nothing and read no code before they answer. Every point their answer leaves open is a question for them. Never fill it in yourself.

3. **Interview.** First read the test skills listed in step 5. Then invoke the `grilling` skill and follow it until its frontier is empty. Find facts yourself; put only decisions to the user. The tree must settle:
   - the behaviour, item by item,
   - what is out of scope,
   - the seams each item is tested at (the `tdd` skill: test only at agreed seams),
   - the one command that proves each item done.

   Ask about a seam only when the test skills leave it open.

4. **Write `plans/<task>/spec.md`** in the format below. Each item has exactly one `check:` command. An item with no check is not ready — go back to the interview, do not invent one.

5. **Write the acceptance tests.** One test per item, at the agreed seam. This is the outer loop that defines done; the red → green loop for each item happens in `/build`. Before you write a test, read the test skills:
   - `tdd/SKILL.md`,
   - `testing`, `frontend-testing` and `no-tautological-tests` in `.devin/skills/`.

   Expected values come from the spec, never from the code.

6. **Review the tests.** First run `git add -N <new test files>` so `git diff` shows them; this commits nothing. Then use the `reviewer` subagent: give it the test files, the same test skills, and the uncommitted diff from the branch's merge base (`git diff $(git merge-base origin/dev HEAD)`). It reviews against the skills only — it did not write the tests. Write its findings to `plans/<task>/test-review.md` and act on each one with a `Result:` line (Fixed with what changed, Skipped with a reason, or Invalid with why), in the format of a build round of the `branch-review` skill but with no commit ids. Repeat the review on the fixes until it reports no Required findings, at most three rounds.

7. **Prove they fail.** Run `.devin/skills/build/spec-check.sh plans/<task>/spec.md`. Every item must report `FAIL` for the right reason (the behaviour is missing, not a typo or a missing import). A check that passes now proves nothing — fix it.

8. **Stop for approval.** Commit nothing, before or after approval. Any text you write comes first. The last lines of the message are the spec path, the list of test files and the path to `test-review.md`, then the line "Reply `approved` to approve the spec, or say what to change." Nothing after it. When they approve, change `Status: draft` to `Status: approved` and tell them to start a new session on this branch with `/build`. If they want changes, make them and repeat from step 6.

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
- [ ] 2. ...
```

A check is one shell command run from the repo root, for example `pnpm --filter @app/frontend exec vitest run src/pages/Results/Results.test.tsx`. Keep it to the one test file, so it is fast.

`/build` ticks items (`[x]`) and may mark an item blocked (`[!]` with a `blocked:` line) when the check or test itself is wrong. Nothing else in the spec changes after approval.
