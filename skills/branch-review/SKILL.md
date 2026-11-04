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

1. **Prepare.** Run the script. It does every step that needs no judgement:

   ```bash
   .claude/skills/branch-review/review-prep.sh "<first argument>" "<second argument>" "<third argument>"
   ```

   It checks out the target and prints `ORIGINAL`, `TARGET`, `BASE`, `MERGE_BASE`, `FROM`
   and `REPORT_FILE`. Then it prints the reviewer's input: one batch (more only for a diff
   too large for one reviewer), with its file count, the skills that apply and the chunk
   files holding those skills and the numbered diff. Then it prints the oxlint errors in the
   changed files, and last the jscpd clones that touch them. Do not repeat any of this work
   yourself, and do not read the chunk files.

   Each oxlint error is a Required finding as printed: cite its file, line and rule. Do not
   look for lint-level issues yourself, and do not pass lint output to the reviewers.

   `FROM` is the merge base, or the `since` commit when one is given. Every diff below is
   taken from `FROM`.

2. **Project standards.** The skills come from `skill-globs.txt`: a skill loads only when a
   changed file matches its glob and, where the line has a regex, when a line the diff adds
   matches it. They are already in the chunk files.

3. **Analyze each batch** in the `reviewer` subagent (the Agent tool, `subagent_type: reviewer`),
   one per batch, all launched in the same message. Give each one its chunk file paths,
   `FROM` and `TARGET`, and nothing else. Merge their findings.

4. **Cross-reference the codebase**
   - Search for similar existing patterns and duplication opportunities
   - Verify consistency with existing code
   - Identify reusable components/functions

   The `## jscpd` part of the script output lists the clones that touch the changed files,
   each with both halves as `file:start-end` and the `fragment`. jscpd reads `.jscpd.json`
   at the repo root.

   jscpd only finds candidates. Read both halves of each clone the script printed and decide:

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
     report, pipe every finding to the script, one per line as
     `<file><TAB><line><TAB><quote>`:

     ```bash
     .claude/skills/branch-review/check-quotes.sh
     ```

     `MOVED`: correct the reference to the line it gives. `MISSING`: drop the finding.

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
   - Write the report to the `REPORT_FILE` the script printed. A build round keeps the review in the repo with the spec (`plans/<branch>/`, made by
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

## Verifying a claim about backend data

Never assert what an API returns from frontend fixtures alone — fixtures go stale. Read the
backend enum or DTO and cite the file and line. If the source is not available, say the
claim is unverified instead of inferring one.

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
