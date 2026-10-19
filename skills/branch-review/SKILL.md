---
name: branch-review
description: Review any branch — check diff, analyze code against standards, provide recommendations
argument-hint: "[branch] [base] [since]"
disable-model-invocation: true
---

# Branch Review

Review a branch by analyzing its changed files against project standards and providing actionable recommendations.

Arguments, in order: `$ARGUMENTS`

- Branch to review: the first argument (defaults to the current branch if empty)
- Base branch to compare against: the second argument (defaults to the remote's default
  branch if empty)
- Review only the commits after: the third argument (optional — a commit id). Only `/build` passes it:
  the merge base in round 1, then the last reviewed commit, so a later round reviews only
  the fixes. With a third argument the review is a **build round**; without it, a **standalone review**.

## Steps

1. **Setup and identify changes**

   ```bash
   ARG_BRANCH="<first argument, or empty>"
   ARG_BASE="<second argument, or empty>"
   ARG_SINCE="<third argument, or empty>"
   ORIGINAL=$(git branch --show-current)
   TARGET="${ARG_BRANCH:-$ORIGINAL}"
   BASE="${ARG_BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')}"
   git fetch origin $BASE
   git ls-remote --exit-code --heads origin $TARGET >/dev/null && git fetch origin $TARGET
   git checkout $TARGET
   MERGE_BASE=$(git merge-base origin/$BASE $TARGET)
   SINCE="$ARG_SINCE"
   FROM="${SINCE:-$MERGE_BASE}"
   CHANGED_FILES=$(git diff --name-only $FROM $TARGET -- "*.ts" "*.tsx" "*.js" "*.jsx" "*.css" "*.json" | grep -v "node_modules" | grep -v "\.d\.ts$")
   ```

   `FROM` is the merge base, or the `since` commit when one is given — every diff below
   is taken from `FROM`.

2. **Load project standards**
   Read `AGENTS.md`, the `review-*` skills in `.claude/skills/`, and the skills that
   `.claude/skills/skills-for-files.sh` names for the changed files:

   ```bash
   echo "$CHANGED_FILES" | .claude/skills/skills-for-files.sh
   ```

3. **Analyze each changed file** in `$CHANGED_FILES`:

   Do this in the `reviewer` subagent (the Agent tool, `subagent_type: reviewer`), so the
   findings never come from the context that wrote the code. For a large diff, launch one
   `reviewer` per package, all in the same message, and merge their findings.

   - Read the current version on the branch
   - Read the diff: `git diff $FROM $TARGET -- $file`
   - Review a file and its colocated test (`foo.ts` + `foo.test.ts`) as one unit — a
     finding in one is usually explained by the other
   - Apply standards: code patterns, file structure, testing coverage, documentation
   - Identify violations, patterns, opportunities, risks

4. **Cross-reference the codebase**
   - Search for similar existing patterns and duplication opportunities
   - Verify consistency with existing code
   - Identify reusable components/functions

   If the repo has `.jscpd.json` at its root, detect copied code with jscpd:

   ```bash
   node_modules/.bin/jscpd ./apps ./packages --baseline-from-ref $MERGE_BASE \
     --absolute --reporters json --silent --no-tips
   ```

   jscpd only finds candidates. Read both halves of each clone that touches `$CHANGED_FILES`
   and decide:

   - Drop it if the halves differ in values, not just names.
   - Drop repeated style blocks unless one is a copy of a shared style module.
   - Keep code clones: functions, hooks, logic, column definitions, components.
   - If it already existed at `$MERGE_BASE` (check with `git show`), it can only be Consider.

   Put a `## jscpd` section straight under the verdict. List every kept clone in it, each
   with what is repeated, both halves as `file:start-end`, and the repeated code (the
   `fragment`) in a fenced block; do not point elsewhere for them. Then one line per reason
   for what you dropped. The verdict line gives both counts:

   ```
   jscpd: 17 clones reported, 1 kept.
   ```

   - Drop `--absolute` and paths come back relative to the scanned roots, matching nothing
     in `$CHANGED_FILES`. Use `$MERGE_BASE`, not `origin/$BASE`, or commits landed on the
     base branch since the branch point count as this branch's duplication.
   - Never quote the overall percentage; it counts the whole repo, not this branch.
   - Anything under `minLines`/`minTokens`, or duplicated in behaviour rather than text, is
     only findable by the read above. Report each clone once, under whichever found it.

   **jscpd finding zero clones does not mean there is no duplication.** A solved problem
   solved again, in a new file with new names, shares no tokens. Search for it yourself.

5. **Generate review report**
   - Summary: `$TARGET` vs `$BASE`, assessment (COMPLIANT / NEEDS_WORK / BLOCKING)
   - Report only what you verified. A finding you cannot tie to a line the diff added or
     changed does not go in, not as a lower severity, not as "worth noting", not as a
     follow-up. A short report is the good outcome; never lengthen one to look thorough.
   - Position check: every finding quotes the exact line it cites. Before writing the
     report, locate each quote with `grep -nF` in the named file. If the quote is not at
     the cited line, correct the reference; if it cannot be located at all, the finding
     is dropped.
   - Reflection pass: re-read each Required finding against the file one final time and
     keep it only if you would stake the verdict on it being a real defect. Fewer, certain
     findings beat coverage — a false alarm costs more trust than a miss.
   - Never review git itself — commit messages, subjects, counts, branch names and history
     shape are out of scope. Commits get squashed on merge, so a finding about them is
     worthless. Review the code the diff changed and nothing else.
   - The report is a verdict plus the action items. Each finding appears once, cited by file,
     line, severity and the skill it references.
   - Action items grouped: Required (blocking) / Recommended / Consider. Consider holds
     verified, in-scope findings the author may reasonably decline, never a weak one
     demoted to fill the section. Omit any category or group with nothing in it.
   - Where the report goes depends on whether this is a build round:

     ```bash
     if [ -n "$SINCE" ]; then
       REPORT_FILE="plans/$TARGET/review.md"
     else
       REPORT_FILE="${TMPDIR:-/tmp}/branch-review-$(echo "$TARGET" | tr '/' '-').md"
     fi
     ```

     A build round keeps the review in the repo with the spec (`plans/<branch>/`, made by
     `/spec`), so the whole task can be audited afterwards. A standalone review writes to
     the system temp dir, **not** a repo folder, so it is never committed by accident.

   - A build round keeps the report in rounds. If the report file already exists,
     **append** a new `## Round N — since <commit>` section; never rewrite earlier rounds.
     Otherwise the report is `## Round 1 — since <merge base>`. Each finding is a
     `### N.k <title>` heading (round, finding) so a finding keeps its id across rounds;
     `spec-check.sh --finish` reads these headings. A standalone review writes
     a single report with findings numbered `1`, `2`, ….

   - End the chat output with a clickable link to the report, not a bare path — a long
     temp path wraps over several lines and stops being clickable. Use a markdown link
     (`[report](file:///...)`). The link is the last thing in the chat output: the
     recommendations and verdict of steps 6 and 7 go in the report and come before the link.
     Write nothing after it.

6. **Provide recommendations** — specific code changes with examples, links to skills, refactoring and testing suggestions.

7. **Final assessment** — state a clear verdict:
   - COMPLIANT: ready to merge
   - NEEDS_WORK: address recommendations before merge
   - BLOCKING: must fix required issues

8. **Cleanup**

   ```bash
   git checkout $ORIGINAL
   ```

## Keeping the report current

Touch a finding only when it is resolved — not after every edit, and not to record
verification runs. How depends on whether this is a build round.

**In a standalone review** the report file is the live state of the review, not a one-off
snapshot:

- A finding that is fixed is **deleted**, not annotated. Renumber what is left and
  correct the count in the verdict line.
- A finding that turns out to be wrong is deleted, and the correction is stated in the
  chat reply.
- Re-check the rest of the file for entries the fix made stale (verification commands
  that now pass, "pre-existing" notes that no longer hold).

**In a build round**, and in `/spec`'s `test-review.md`, the report is the record of the
review: the reader audits it after the fact, so nothing in it is deleted. Add one `Result:`
line directly under the finding's heading:

- `Result: Fixed — <what changed>`.
- `Result: Skipped — <reason>` — a reason the reader can judge, not "out of scope".
- `Result: Invalid — <why the finding was wrong>`.
- `Result: Repeated — came back after <finding id> was fixed; left for the user`.
- `Result: Open` — not acted on; the reader decides.

Keep the Where-to-Comment table and Action Items in step with the results.

## Assessment scale

| Status     | Criteria                                    | Action           |
| ---------- | ------------------------------------------- | ---------------- |
| COMPLIANT  | Follows all standards, no blocking issues   | Proceed with PR  |
| NEEDS_WORK | Minor issues, mostly compliant              | Fix before merge |
| BLOCKING   | Critical violations or missing requirements | Fix required     |

## Review principles

- Focus on changed code (the diff), not entire files
- Apply standards pragmatically — not every rule applies to every change
- Provide actionable recommendations with examples
- Note positive patterns as well as issues
- Consider context — quick fix vs new feature
- Suggest incremental improvements for legacy code touchpoints
