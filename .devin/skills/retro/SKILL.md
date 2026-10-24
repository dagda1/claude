---
name: retro
description: After you have audited a finished task, find what the harness got wrong and propose at most one change to a skill or check so it does not happen again.
triggers:
  - user
---

# Retro

The task is the current branch (`git branch --show-current`). If it is `dev`, stop and say so. Run this after the user has reviewed the task's changes.

The goal is the steering loop: a mistake that reached the user becomes a rule (a skill) or a check, so it cannot come back. But every rule added to a skill costs context on every run, so a task gives at most one lesson, and only when the evidence supports it. Propose; never change a skill or a check without the user's approval.

## Steps

1. **Collect the evidence** from `plans/<task>/`:
   - `log.md`: written by hooks, not by an agent. Every message the user sent, every failed tool call, every time the Stop hook blocked the build. The user's messages are the strongest evidence: each correction is a place the harness went wrong.
   - `spec.md`, `test-review.md`, `review.md` and `summary.md`: what was agreed and what the reviews found.
   - `git status` and `git diff`: what the user has kept, changed or discarded from the build.

2. **List the problems.** One line each, with its evidence (a line of `log.md`, a finding id, an item number):
   - a correction or complaint in the user's messages,
   - a change the user discarded or rewrote,
   - a command that failed again and again, or a Stop-hook block,
   - a finding marked Repeated, or Skipped or Invalid when the user disagrees,
   - an item marked blocked (`[!]`): the spec or its check was wrong.

   For each problem, give its cause only when the evidence isolates it. When several things could explain it (for example, the build changed several things at once, or there is only one occurrence), write **confounded** and name the possible causes. Do not guess a cause.

   Then read the earlier `plans/*/retro.md` files (list them with `git ls-files 'plans/*retro.md'`) and the `## Rules` table in `AGENTS.md`. Mark a problem as **repeated** when it already appears in an earlier retro, or when it breaks a rule in the table that nothing enforces. Give the earlier file or the rule.

3. **Write `plans/<task>/retro.md`** for the user, in plain English, in exactly this format. No ids, timestamps, tables or field labels. With no lesson, Proposed fix says `No lesson.` and there is no Code section.

   ````markdown
   # <task> — retro

   ## What went wrong

   <one line on what went well and what did not>:

   - <one plain sentence per problem>

   ## Proposed fix

   <the one change in plain words. What it fixes, and what it leaves.>

   ## Code

   In `<file>`, <where>:

   ```<lang>
   <the exact code or text>
   ```

   <one line: it fails on this task's mistake and passes on the fix.>
   ````

   Choose the fix with these rules. They guide the choice and do not appear in the report:

   - The fix must fit a different task. "Be thorough" is too general; "the date field was wrong in item 3" never fires again. Aim between: "when a component reads a value that its parent already has, pass it down instead of fetching it again".
   - A lesson that rests only on confounded rows is a guess: narrow it to what the evidence shows, or write no lesson.
   - Use the highest level that works:
     1. **Architecture**: one owner for each piece of state, one way to do each task. Hide internals so the wrong import fails. Delete the old way, so an agent cannot copy it.
     2. **Type**: make the wrong state impossible to write.
     3. **Lint**: when the wrong code still compiles, a lint or CI check whose error names the file, type or function to use instead. If the pattern is already common, fail only when a change adds more.
     4. **Test**: a test of the behaviour that fails when the behaviour breaks.
     5. **Rule**: text in a skill. Use it only for a judgement call: nothing fails when an agent ignores a rule.
   - A repeated problem never gets a rule. It gets a check at level 1 to 4.
   - A check must fail on the real mistake. Write the proof command that runs it against the code from this task that the user corrected (for example, with the user's fix reverted in a temporary copy). A check that has never failed proves nothing.
   - If the lesson adds text to a skill, say which text it removes, or why nothing can go.
   - If nothing supports a lesson, write `No lesson.` This is a valid result: a rule that the evidence does not support costs context and gives nothing.

4. **Stop for approval.** Write the line "Reply `yes` to make the change, or say what to change." (or "No lesson this time." if there is no lesson), then the link to `retro.md`. The link is the last thing in the message. Write nothing after it. Make only the change they approve, then:

   - For a check, run the proof command and show that the check fails on the mistake and passes on the user's fix.
   - Edit `AGENTS.md` only when the approved change is a rule agents must read, or a check that replaces a rule already listed there. A check that enforces itself needs no entry.

   Commit nothing.
