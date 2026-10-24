---
name: spec
description: Agree a spec for a piece of work and write its failing acceptance tests, ready for /build. This is the only conversation before the build.
disable-model-invocation: true
---

# Spec

The task is the current branch (`git branch --show-current`). It is also the folder name. If it is the base branch, stop and say so. The base branch is the remote's default branch: `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||'`.

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

   When a bug fix changes what the user sees, ask the user whether it needs a story that shows the fixed state. A story is only for the user to look at. It is never an item, has no check and no test, and never stands in for one. If they agree, it goes under `## Stories`. Never ask how a story is tested or checked.

4. **Write `plans/<task>/spec.md`** in the format below. Each item has exactly one `check:` command. An item with no check is not ready — go back to the interview, do not invent one.

   Put every fact you verified about the code during the interview under `## Facts`, with the file and line where you found it. Write the fact itself ("`status` in `api/types.ts:42` is `'open' | 'closed'`"), not how to find it, so `/build` does not have to find it again. Only verified facts: a guessed fact is worse than none. Say how each fact is verified, and take each one as far as is cheap:

   1. `file:line`: you read it at that line.
   2. `walked`: you followed the code path and the wrong case cannot happen.
   3. `ran`: you ran code that proves it (a command, a script, or a test), and the output is in the spec.

   A fact that an item's safety depends on must be `ran`.

5. **Write the acceptance tests.** One test per item, at the agreed seam. This is the outer loop that defines done; the red → green loop for each item happens in `/build`. Before you write a test, read the test skills:
   - `tdd/SKILL.md`,
   - `frontend-testing`, `no-tautological-tests` and `code-test-colocation` in `.claude/skills/`.

   Expected values come from the spec, never from the code.

6. **Review the tests.** First run `git add -N <new test files>` so `git diff` shows them; this commits nothing. Then use the `reviewer` subagent (the Agent tool, `subagent_type: reviewer`): give it the test files, the same test skills, and the uncommitted diff from the branch's merge base (`git diff $(git merge-base origin/<base> HEAD)`). It reviews against the skills only — it did not write the tests. Write its findings to `plans/<task>/test-review.md` and act on each one with a `Result:` line (Fixed with what changed, Skipped with a reason, or Invalid with why), in the format of a build round of `.claude/skills/branch-review/SKILL.md` but with no commit ids. Repeat the review on the fixes until it reports no Required findings, at most three rounds.

7. **Prove they fail.** Run `.claude/skills/build/spec-check.sh plans/<task>/spec.md`. Every item must report `FAIL` for the right reason (the behaviour is missing, not a typo or a missing import). A check that passes now proves nothing — fix it.

8. **Stop for approval.** Commit nothing, before or after approval. Any text you write comes first. Then the line "Reply `approved` to approve the spec, or say what to change." Then the links to the spec, each test file and `test-review.md`, one per line. Write each link as a markdown link to the absolute path, `[name](file:///absolute/path)`; a relative link does not open in the terminal. The links are the last thing in the message. Write nothing after them. When they approve, change `Status: draft` to `Status: approved` and tell them to start a new session on this branch with `/build`. If they want changes, make them and repeat from step 6.

## Spec format

```markdown
# <task>

Status: draft
Branch: <task>

## Goal

<One or two sentences: what changes for the user of the code.>

## Out of scope

- <What this task does not do.>

## Facts

- <A fact about the code that the build needs.> — <file:line | walked | ran: command and output>

## Items

- [ ] 1. <One behaviour, one sentence.>
  - check: `<command that fails now and passes when the item is done>`
  - test: `<path to the acceptance test>`
- [ ] 2. ...

## Stories

- <Story file and export>: <the state it shows>.
```

Omit `## Stories` when the user asked for no story.

A check is one shell command run from the repo root, for example `pnpm --filter @app/frontend exec vitest run src/pages/Results/Results.test.tsx`. Keep it to the one test file, so it is fast.

`/build` ticks items (`[x]`) and may mark an item blocked (`[!]` with a `blocked:` line) when the check or test itself is wrong. Nothing else in the spec changes after approval.
