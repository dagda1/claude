---
name: spec
description: Agree a spec for a piece of work and write its failing acceptance tests, ready for /build. This is the only conversation before the build.
disable-model-invocation: true
---

# Spec

The task is the current branch (`git branch --show-current`). It is also the folder name. If it is the base branch, stop and say so. The base branch is the remote's default branch: `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||'`.

Everything for the task lives in `plans/<task>/`. This skill writes two files and the acceptance tests: `spec.md` for the user, only the items as short checkboxes, and `llm.md` for the build, everything else. `/build` does the rest in a new session, with no conversation, so the two files must hold everything the build needs.

## Steps

1. **Folder.** `mkdir -p plans/<task>`. If `plans/<task>/spec.md` exists with `Status: draft`, read it and `llm.md`, and carry on from the `## Open` section of `llm.md`. Do not ask again about anything it settles.

2. **Ask what the task is.** Ask the user to describe the task. Search nothing and read no code before they answer. Every point their answer leaves open is a question for them. Never fill it in yourself.

3. **Interview.** First read the test skills listed in step 5. Then invoke the `grilling` skill and follow it until its frontier is empty. Find facts yourself; put only decisions to the user. The tree must settle:
   - the behaviour, item by item,
   - what is out of scope,
   - the seams each item is tested at (the `tdd` skill: test only at agreed seams),
   - the one command that proves each item done, or, for a visual item, the story the user approves it in.

   Ask about a seam only when the test skills leave it open.

   Write both files as you go, in the formats below. When the user settles a decision, put it in them before you ask the next question. When you verify a fact, add it to `## Facts` in `llm.md` straight away. Keep the questions still to be asked under `## Open` in `llm.md`. The two files are the record of the interview. A new session must be able to resume from them alone.

   When a bug fix changes what the user sees, ask the user whether it needs a story that shows the fixed state. A story is only for the user to look at. It is never an item, has no check and no test, and never stands in for a check that a test could make. If they agree, it goes under `## Stories` in `llm.md`. Never ask how a story is tested or checked.

   A visual item is one no test can see without faking the browser, such as layout. It has a `visual:` line naming its story instead of a check. It is visual only when the user agrees no honest test exists. When it cannot be settled in text, build its story and try solutions in it with the user. The picked code stays for `/build` to review.

   If a design screenshot is supplied, go through it element by element before approval. Each element that is new, or differs from ours, becomes an item that names it.

4. **Finish both files.** `## Open` in `llm.md` must be empty; delete it. Each item in `llm.md` has exactly one `check:` command or exactly one `visual:` line. An item with neither is not ready — go back to the interview, do not invent one.

   Put every fact you verified about the code during the interview under `## Facts` in `llm.md`, with the file and line where you found it. Write the fact itself ("`status` in `api/types.ts:42` is `'open' | 'closed'`"), not how to find it, so `/build` does not have to find it again. Only verified facts: a guessed fact is worse than none. Say how each fact is verified, and take each one as far as is cheap:

   1. `file:line`: you read it at that line.
   2. `walked`: you followed the code path and the wrong case cannot happen.
   3. `ran`: you ran code that proves it (a command, a script, or a test), and the output is in `llm.md`.

   A fact that an item's safety depends on must be `ran`.

5. **Write the acceptance tests.** One test per item with a check, at the agreed seam. A visual item has no test. This is the outer loop that defines done; the red → green loop for each item happens in `/build`. Before you write a test, read the test skills:
   - `tdd/SKILL.md`,
   - `frontend-testing`, `no-tautological-tests` and `code-test-colocation` in `.claude/skills/`.

   Expected values come from the spec, never from the code.

6. **Review the tests.** First run `git add -N <new test files>` so `git diff` shows them; this commits nothing. Then use the `reviewer` subagent (the Agent tool, `subagent_type: reviewer`): give it the test files, the same test skills, and the uncommitted diff from the branch's merge base (`git diff $(git merge-base origin/<base> HEAD)`). It reviews against the skills only — it did not write the tests. Write its findings to `plans/<task>/test-review.md` and act on each one with a `Result:` line (Fixed with what changed, or Open with what the fix would break), in the format of a build round of `.claude/skills/branch-review/SKILL.md` but with no commit ids. Repeat the review on the fixes until it reports no Required findings, at most three rounds.

7. **Prove they fail.** Run `.claude/skills/build/spec-check.sh plans/<task>/spec.md`. Every item with a check must report `FAIL` for the right reason (the behaviour is missing, not a typo or a missing import). A check that passes now proves nothing — fix it. A visual item reports `VISUAL`. When no item has a test, skip steps 6 and 7's test work and link no test files or `test-review.md` in step 8.

8. **Stop for approval.** Commit nothing, before or after approval. Any text you write comes first. Then the line "Reply `approved` to approve the spec, or say what to change." Then the links to `spec.md`, each test file and `test-review.md`, one per line. Write each link as a markdown link to the absolute path, `[name](file:///absolute/path)`; a relative link does not open in the terminal. The links are the last thing in the message. Write nothing after them. When they approve, change `Status: draft` to `Status: approved` and tell them to start a new session on this branch with `/build`. If they want changes, make them and repeat from step 6.

## spec.md format

The user reads only this file. Each item is one short line of what the user will see, with no file names, reasons or detail.

```markdown
# <task>

Status: draft

- [ ] 1. Starring a group card stays on the page.
- [ ] 2. ...
```

## llm.md format

```markdown
# <task>

## Goal

<One or two sentences: what changes for the user of the code.>

## Out of scope

- <What this task does not do.>

## Facts

- <A fact about the code that the build needs.> — <file:line | walked | ran: command and output>

## Items

- 1. <The detail the build needs for item 1 of spec.md.>
  - check: `<command that fails now and passes when the item is done>`
  - test: `<path to the acceptance test>`
- 2. <Detail for a visual item.>
  - visual: <story file and export>

## Stories

- <Story file and export>: <the state it shows>.

## Open

- <A decision not yet put to the user.>
```

Item numbers in `llm.md` match `spec.md`. Omit `## Stories` when the user asked for no story. Every story a `visual:` line names is listed under `## Stories`.

A check is one shell command run from the repo root, for example `pnpm --filter @app/frontend exec vitest run src/pages/Results/Results.test.tsx`. Keep it to the one test file, so it is fast.

`/build` ticks items in `spec.md` (`[x]`) and may mark one blocked (`[!]` with a `blocked:` line under it) when the check or test itself is wrong. Nothing else changes after approval.
