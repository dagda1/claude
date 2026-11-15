---
name: branch-review
description: Review any branch — check diff, analyze code against standards, provide recommendations
argument-hint: '[branch] [base] [since]'
triggers:
  - user
allowed-tools:
  - read
  - grep
  - glob
  - exec
  - edit
---

# Branch Review

Review a branch by analyzing its changed files against project standards and providing actionable recommendations.

- Branch to review: `$1` (defaults to the current branch if empty)
- Base branch to compare against: `$2` (defaults to `dev` if empty)
- Review only the commits after: `$3` (optional — a commit id). Only `/build` passes it:
  the merge base in round 1, then the last reviewed commit, so a later round reviews only
  the fixes. With `$3` the review is a **build round**; without it, a **standalone review**.

## Steps

1. **Prepare.** Run the script. It does every step that needs no judgement:

   ```bash
   .devin/skills/branch-review/review-prep.sh "$1" "$2" "$3"
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

3. **Analyze each batch** in the `reviewer` subagent, one per batch, all launched in the
   same message. Give each one its chunk file paths, `FROM` and `TARGET`, and nothing else.
   Merge their findings. Where subagents aren't available (Cascade), read the chunks and
   review each batch yourself.

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

   Each kept clone is a finding like any other, with what is repeated, both halves as
   `file:start-end`, and the repeated code (the `fragment`) in a fenced block. Dropped
   clones are not written down; the verdict line gives both counts and nothing else:

   ```
   jscpd: 17 clones reported, 1 kept.
   ```

   - Never quote the overall percentage; it counts the whole repo, not this branch.
   - Anything under `minLines`/`minTokens`, or duplicated in behaviour rather than text, is
     only findable by the read above. Report each clone once, under whichever found it.

   **jscpd finding zero clones does not mean there is no duplication.** A solved problem
   solved again, in a new file with new names, shares no tokens. Run the diff grep in
   `rjsf-first` and state its result in the verdict line beside the jscpd count:

   ```
   jscpd: 0 clones reported. schema reads: 5, all in the two sanctioned walkers.
   ```

   An unaccounted hit is Required and the verdict is BLOCKING.

5. **Generate review report**
   - Summary: `$TARGET` vs `$BASE`, assessment (COMPLIANT / NEEDS_WORK / BLOCKING)
   - Report only what you verified. Code in a changed file counts, including code that was
     only moved or that predates the branch; never drop a finding for that reason. The
     user decides scope.
   - Position check: every finding quotes the exact line it cites. Before writing the
     report, pipe every finding to the script, one per line as
     `<file><TAB><line><TAB><quote>`:

     ```bash
     .devin/skills/branch-review/check-quotes.sh
     ```

     `MOVED`: correct the reference to the line it gives. `MISSING`: drop the finding.

   - Reflection pass: re-read each Required finding against the file one final time and
     keep it only if you would stake the verdict on it being a real defect. Fewer, certain
     findings beat coverage — a false alarm costs more trust than a miss.
   - Never review git itself — commit messages, subjects, counts, branch names and history
     shape are out of scope. Commits get squashed on merge, so a finding about them is
     worthless. Review the code the diff changed and nothing else.
   - Never flag a dependency for being newly published. `pnpm-workspace.yaml` sets
     `minimumReleaseAge: 0` deliberately; there is no release-age rule in this repo.
   - The report is a verdict plus the action items. Each finding appears once, cited by file,
     line, severity and the skill it references.
   - Action items grouped: Required (blocking) / Recommended / Consider. Consider holds
     verified, in-scope findings the author may reasonably decline, never a weak one
     demoted to fill the section. Omit any category or group with nothing in it.
   - Write the report to the `REPORT_FILE` the script printed. A build round keeps the review in the repo with the spec (`plans/<branch>/`, made by
     `/spec`), so the whole task can be audited afterwards. A standalone review writes to
     the system temp dir, **not** a repo folder: a repo `tmp/` is gitignored and Cascade's
     write tool silently skips gitignored paths, while any other repo folder ends up
     committed by accident.

   - The report holds open findings only, in a build round as in a standalone review. A
     later round adds its new findings to the same groups; it never adds a round section,
     a history, a list of what passed, or a list of dropped clones. In a build round each
     finding is a `### N.k <title>` heading (round, finding), so an id is never reused and
     `spec-check.sh --finish` can read it. A standalone review numbers findings `1`, `2`, ….

   - End the chat output with a clickable link to the report, not a bare path — a long
     temp path wraps over several lines and stops being clickable. In Devin use a
     `<ref_file file="..." />` tag; in Cascade use a markdown link (`[report](file:///...)`).

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

The report is the live list of what is still open, never a record. Touch a finding only
when it is resolved — not after every edit, and not to record verification runs.

- A finding that is fixed is **deleted**, not annotated. The fix commit
  (`fix(<task>): review <id> — <what>`) is the record of it.
- A finding that turns out to be wrong is deleted, and the correction is stated in the
  chat reply.
- A finding left for the user stays, with one line under its heading:
  - `Result: Open — <why it was not fixed>`.
  - `Result: Repeated — came back after <finding id> was fixed; left for the user`.
    Check the `review <id>` fix commits to tell a repeat from a new finding.
- Correct the counts in the verdict line, and re-check the rest of the file for entries a
  fix made stale.
- The report never grows a section for what is done.

## Verifying a claim about backend data

Never assert what an API returns from frontend fixtures alone — fixtures go stale. The
backend is checked out beside this repo (`../harbour`, submodules such as
`harbour-common-libraries` and `harbour-platform-service`); read the enum or DTO and cite
the file and line. If the source is not available, say the claim is unverified instead of
inferring one.

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
