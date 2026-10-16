---
name: retro
description: After you have audited a finished task, find what the harness got wrong and propose changes to skills or checks so it does not happen again.
argument-hint: "[task-name]"
triggers:
  - user
---

# Retro

The task name is the argument given after `/retro`. Run this after the user has audited the task and reverted what they disagree with.

The goal is the steering loop: every mistake that reached the user becomes a rule (a skill) or a check, so it cannot come back. Propose; never change a skill or a check without the user's approval.

## Steps

1. **Record the results.** Run `.devin/skills/build/metrics.sh --record <task>`. It now counts the commits the user reverted.

2. **Collect the evidence** from `plans/<task>/`: `spec.md`, `test-review.md`, `review.md`, `summary.md`, and the reverted commits (`git log --all --format='%h %s' -E --grep='^Revert "(feat|fix)\(<task>\)'`). For each reverted commit, read its diff and the finding or item it came from.

3. **Ask the user one question:** what did they change by hand that is not in a revert? Wait for the answer.

4. **List the problems.** One line each, with its evidence (finding id, commit, item number):
   - a commit the user reverted, or a change they made by hand,
   - a finding marked Repeated,
   - a finding marked Skipped or Invalid that the user disagrees with,
   - an item marked blocked (`[!]`) — the spec or its check was wrong.

5. **Look across tasks.** Read `plans/metrics.csv` and the `review.md` of earlier tasks. A skill cited in findings in two or more tasks is a rule the agent does not follow when it writes code. That is a stronger case for a check than for more words in the skill.

6. **Write `plans/<task>/retro.md`.** For each problem, one proposal:
   - **Problem** — what went wrong, with the evidence.
   - **Change** — one of: a new or reworded rule in a named skill (give the exact text), a new check (a lint rule, a test, or a line in a hook), or a change to `spec`, `build` or `branch-review`. Prefer a check over a rule when the same problem is in more than one task.
   - **Expected effect** — which column of `plans/metrics.csv` should go down.

   Keep each proposal short. No proposal without evidence.

7. **Stop for approval.** Give the user the path to `retro.md`, nothing else. Make only the changes they approve, then commit them with `plans/metrics.csv` and `retro.md`: `chore(retro): <task>`.
