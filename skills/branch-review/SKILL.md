---
name: branch-review
description: Review any branch — check diff, analyze code against standards, provide recommendations
argument-hint: "[branch] [base] [since]"
triggers:
  - user
allowed-tools:
  - read
  - grep
  - glob
  - exec
  - write
---

# Branch Review

Review a branch by analyzing its changed files against project standards and providing actionable recommendations.

- Branch to review: `$1` (defaults to the current branch if empty)
- Base branch to compare against: `$2` (defaults to the remote's default branch if empty)
- Review only the commits after: `$3` (optional — a commit id; `/build` passes the last
  reviewed commit so a later round reviews only the fixes)

## Steps

1. **Setup and identify changes**

   ```bash
   set -euo pipefail
   ORIGINAL=$(git branch --show-current)
   TARGET="${1:-$ORIGINAL}"
   BASE="${2:-$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')}"
   git fetch origin $BASE
   git ls-remote --exit-code --heads origin $TARGET >/dev/null && git fetch origin $TARGET
   git checkout $TARGET
   MERGE_BASE=$(git merge-base origin/$BASE $TARGET)
   SINCE="${3:-}"
   FROM="${SINCE:-$MERGE_BASE}"
   CHANGED_FILES=$(git diff --name-only $FROM $TARGET -- . \
     ':(exclude)**/node_modules/**' \
     ':(exclude)**/*.lock' ':(exclude)**/*-lock.json' ':(exclude)**/*.d.ts' \
     ':(exclude)plans/**')
   ```

   `BASE` comes from the remote's default branch, so this works on a `main` project and a
   `dev` one. `FROM` is the merge base, or the `since` commit when one is given — every
   diff below is taken from `FROM`. `CHANGED_FILES` covers every file type — backend,
   config, markdown — not just frontend sources. `plans/` holds the spec and the review
   itself, so it is never reviewed.

   If any step after this one fails, run `git checkout $ORIGINAL` before reporting.

2. **Load project standards**

   Read `AGENTS.md`. Then select which skills to load using
   `.devin/skills/skills-map.txt` — a file of `glob : skill-names` lines mapping file
   patterns to the skills that apply to them. `skills-for-files.sh` (same directory)
   reads that map for you: pipe it the changed files and it prints the skill names.
   Never load the whole skill set:

   ```bash
   SKILLS=$(echo "$CHANGED_FILES" | .devin/skills/skills-for-files.sh)
   echo "$SKILLS" | sed 's|^|.devin/skills/|;s|$|/SKILL.md|'
   ```

   Read only the SKILL.md files that command prints, plus every `review-*` skill
   (`ls .devin/skills/review-*/SKILL.md`). When splitting step 3 across subagents,
   run the script per package's file list and give each subagent only its own skills.

   Fallback: if `skills-for-files.sh` is missing, `ls .devin/skills/*/SKILL.md` and
   read everything, as before.

3. **Analyze each changed file** in `$CHANGED_FILES`:

   For a large diff, split this across one background subagent per package, all launched in
   the same message, and merge their findings. Where subagents aren't available (Cascade),
   work through the packages sequentially in a single pass.

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
   - If the project has jscpd, run it over the changed `.ts`/`.tsx` files
     (`scripts/jscpd-staged.sh <files>` when that script exists, otherwise
     `pnpm exec jscpd <files>`). jscpd output is a lead, not a finding: report a clone only
     when it is a whole function or a repeated piece of logic worth extracting. Drop
     fragments — matching imports, JSX scaffolding, a few shared lines inside otherwise
     different functions.

5. **Generate review report**
   - Summary: `$TARGET` vs `$BASE`, assessment (COMPLIANT / NEEDS_WORK / BLOCKING)
   - Report only what you verified. A finding you cannot tie to a line the diff added or
     changed does not go in, not as a lower severity, not as "worth noting", not as a
     follow-up. A short report is the good outcome; never lengthen one to look thorough.
   - The report is a verdict plus the action items. Each finding appears once, cited by file,
     line, severity and the skill it references.
   - Action items grouped: Required (blocking) / Recommended / Consider. Consider holds
     verified, in-scope findings the author may reasonably decline, never a weak one
     demoted to fill the section. Omit any category or group with nothing in it.
   - Where the report goes depends on whether the branch has a task folder:

     ```bash
     if [ -d "plans/$TARGET" ]; then
       REPORT_FILE="plans/$TARGET/review.md"
     else
       REPORT_FILE="${TMPDIR:-/tmp}/branch-review-$(echo "$TARGET" | tr '/' '-').md"
     fi
     ```

     A task folder (`plans/<branch>/`, made by `/spec`) keeps the review in the repo with
     the spec, so the whole task can be audited afterwards. Without one, write to the
     system temp dir, **not** a repo folder: a repo `tmp/` is gitignored and Cascade's
     write tool silently skips gitignored paths, while any other repo folder ends up
     committed by accident.

   - When `$3` (since) is given and the report file already exists, **append** a new
     `## Round N — since <commit>` section; never rewrite earlier rounds. Otherwise the
     report is `## Round 1 — since <merge base>`. Number findings `N.k` (round, finding)
     so a finding keeps its id across rounds.

   - End the chat output with the report's absolute path so the reader can open the full
     report.

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

The report is the record of the review: the reader audits it after the fact, so nothing
in it is deleted. Touch a finding only when it is resolved — not after every edit, and not
to record verification runs. Add one `Result:` line directly under the finding's heading:

- `Result: Fixed — <commit id>` — one commit per finding, so the fix can be reverted alone.
- `Result: Skipped — <reason>` — a reason the reader can judge, not "out of scope".
- `Result: Invalid — <why the finding was wrong>`.
- `Result: Repeated — came back after <finding id> was fixed; left for the user`.
- `Result: Open` — not acted on; the reader decides.

Keep the Where-to-Comment table and Action Items in step with the results.

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
