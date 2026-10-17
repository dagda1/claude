---
name: retro
description: After you have audited a finished task, find what the harness got wrong and propose changes to skills or checks so it does not happen again.
triggers:
  - user
---

# Retro

The task is the current branch (`git branch --show-current`). If it is `dev`, stop and say so. Run this after the user has reviewed the task's changes.

The goal is the steering loop: every mistake that reached the user becomes a rule (a skill) or a check, so it cannot come back. Propose; never change a skill or a check without the user's approval.

## Steps

1. **Collect the evidence** from `plans/<task>/`:
   - `log.md`: written by hooks, not by an agent. Every message the user sent, every failed tool call, every time the Stop hook blocked the build. The user's messages are the strongest evidence: each correction is a place the harness went wrong.
   - `spec.md`, `test-review.md`, `review.md` and `summary.md`: what was agreed and what the reviews found.
   - `git status` and `git diff`: what the user has kept, changed or discarded from the build.

2. **Ask the user one question:** what did they change or discard, and why? Wait for the answer.

3. **List the problems.** One line each, with its evidence (a line of `log.md`, a finding id, an item number):
   - a correction or complaint in the user's messages,
   - a change the user discarded or rewrote,
   - a command that failed again and again, or a Stop-hook block,
   - a finding marked Repeated, or Skipped or Invalid when the user disagrees,
   - an item marked blocked (`[!]`): the spec or its check was wrong.

   Then read the earlier `plans/*/retro.md` files (list them with `git ls-files 'plans/*retro.md'`). Mark any problem that already appears in one of them as **repeated**, with the earlier file.

4. **Write `plans/<task>/retro.md`.** For each problem, one proposal:
   - **Problem**: what went wrong, with the evidence.
   - **Change**: one of a new or reworded rule in a named skill (give the exact text), a new check (a lint rule, a test, or a hook), or a change to `spec`, `build` or `branch-review`. Prefer a check over a rule when the agent has already ignored the rule; a repeated problem always gets a check.

   Keep each proposal short. No proposal without evidence.

5. **Stop for approval.** Give the user the path to `retro.md`, then end with the line "Reply with the numbers of the proposals to make, or say what to change." Nothing else. Make only the changes they approve. Commit nothing.
