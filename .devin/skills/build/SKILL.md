---
name: build
description: Build an approved spec with no conversation — make every check pass, run up to three review rounds, and write a summary the user audits afterwards.
triggers:
  - user
---

# Build

Task: the current branch (`git branch --show-current`). If it is `dev`, stop and say so. Spec: `plans/<task>/spec.md` holds the items you tick; `plans/<task>/llm.md` holds their detail, checks, facts and stories.

Do not ask the user anything. Every decision you make goes into a file they read afterwards: the spec, `review.md` or `summary.md`. A decision that is not written down did not happen.

## Start

1. `.devin/skills/build/spec-check.sh --start plans/<task>/spec.md`. It refuses a spec that is not approved — then stop and say so. From now on a Stop hook keeps you working while any item is open. The commits you make are checkpoints only; `--finish` turns them back into uncommitted changes. If the user stops the build, run `--uncommit` yourself; never ask the user to run `spec-check.sh`.
2. Read `plans/<task>/spec.md`, `plans/<task>/llm.md`, `AGENTS.md`, `file-placement`, `tdd/SKILL.md`, `testing`, `frontend-testing` and `no-tautological-tests`. Every test you write follows these test skills; the review rounds check it against them. Read no other skill now: each item loads the skills its code needs (Items, step 5).

## Items

Work the items in order, one at a time:

1. Make the item's check pass with the `tdd` red → green loop: the smallest failing test, the least code to pass it, repeat.
2. Search before you create any function or component. Reuse what exists.
3. Run the item's check. Do not start the next item while it is red.
4. Commit: `feat(<task>): item <N> — <behaviour>`. Stage only the files the item changed. Never stage anything under `plans/`. Then tick the item in `spec.md` (`[x]`).
5. Get the skills for the item's code:

   ```bash
   .devin/skills/branch-review/skills-for.sh HEAD~1 HEAD $(git diff --name-only HEAD~1 HEAD)
   ```

   Read each skill it prints that you have not read yet. If the item's code breaks one, fix it, run the check again, and commit `refactor(<task>): item <N> — <skill>`.

A visual item (a `visual:` line in place of a check) has no test and no check. Make the change, commit as in step 4 and tick it. Its story is made with the others below. List it under "Check in Storybook" in the summary; the user approves it there.

After the last item, make each story under `## Stories` in `llm.md`, following the `storybook` skill. Write no test for a story. Commit: `feat(<task>): story — <export>`.

Never edit an item's check or acceptance test to make it pass. If you are sure the check or test is wrong, mark the item `[!]` in `spec.md`, add `blocked: <why>` under it, and continue with the next item. Blocked is for a wrong check, never for a hard one.

## Review rounds

Run at most three rounds. Round 1 reviews the whole branch; each later round reviews only the commits since the previous round started.

1. Note `SINCE=$(git rev-parse HEAD)` for the next round.
2. Follow the `branch-review` skill with arguments `<task> dev <since>` (`since` is `git merge-base origin/dev HEAD` in round 1). Run its file analysis (step 3) in the `reviewer` subagent even for a small diff, so the findings never come from the context that wrote the code. The report goes to `plans/<task>/review.md`.
3. Act on every finding of the round, as that workflow's "Keeping the report current" describes: delete a fixed finding from `review.md`, and give an Open or Repeated one a `Result:` line:
   - **Fix** it: one commit per finding, `fix(<task>): review <id> — <what>`. Never stage anything under `plans/`.
   - **Open**: only when the fix would break a check or the acceptance test. Write what it breaks; the user decides. Never leave a finding Open because the code predates the branch, was only moved, or the spec did not mention it.
   - **Repeated**: a finding that comes back after it was fixed in an earlier round. Do not fix it again; leave it for the user.
4. Run `.devin/skills/build/spec-check.sh plans/<task>/spec.md`. A fix that breaks a check is reverted, and the finding is marked Open with what it breaks.
5. Stop the rounds when the round had no Required findings, when a finding was Repeated, or after round 3. Otherwise start the next round from step 1.

## Finish

1. Write `plans/<task>/summary.md` in the format below. No bullet over 25 words.
2. `.devin/skills/build/spec-check.sh --finish`. It refuses a summary with a longer bullet.
3. Commit nothing: `--finish` has already uncommitted the build's commits, so every change is in the working tree for the user to review.
4. Never run the full build, test suite, typecheck or lint. The user and CI run those. Never start Storybook: it is a process the user cannot stop.
5. Your final message is the verdict, then the link to `summary.md`. The link is the last thing in the message. Write nothing after it.

## Summary format

```markdown
# <task> — build summary

Verdict: <verdict of the last review> · Rounds: <n> · Stopped because: <no Required findings | repeated finding | 3 rounds>

## Needs your decision

- <Every blocked item, open or repeated finding, and skipped finding — one line each, with its id in review.md.>

## Check in Storybook

- `pnpm --filter <package> storybook`, then [<story name>](http://localhost:<port>/?path=/story/<story id>): <what it should show and what to try>. For a visual item, start with `Item <N> (visual):`.
```

Take the port from the `storybook` script in the package's `package.json`. The story id is the meta `title` and the export name, each lower-cased and kebab-cased, joined by `--`.

Omit "Needs your decision" when there is nothing in it. Omit "Check in Storybook" when the spec asked for no story.
