---
name: branch-review
description: Review any branch — check diff, analyze code against standards, provide recommendations
argument-hint: "[branch] [base]"
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
- Base branch to compare against: `$2` (defaults to `dev` if empty)

## Steps

1. **Setup and identify changes**

   ```bash
   ORIGINAL=$(git branch --show-current)
   TARGET="${1:-$ORIGINAL}"
   BASE="${2:-dev}"
   git fetch origin $BASE $TARGET
   git checkout $TARGET
   MERGE_BASE=$(git merge-base origin/$BASE $TARGET)
   CHANGED_FILES=$(git diff --name-only $MERGE_BASE $TARGET -- "*.ts" "*.tsx" "*.js" "*.jsx" "*.css" "*.json" | grep -v "node_modules" | grep -v "\.d\.ts$")
   ```

2. **Load project standards**
   Read `AGENTS.md` and the relevant skills in `.claude/skills/` (code-error-handling, code-no-defensive-fallbacks, code-style-defaults, code-test-colocation, code-trust-the-types, frontend-api-calls, frontend-bundle-imports, frontend-component-structure, frontend-mui-theming, frontend-no-boolean-params, frontend-no-render-functions, frontend-prefer-router-links, frontend-react-query, frontend-react-typescript, frontend-routing, frontend-suspense, frontend-testing, frontend-zod-validation, no-tautological-tests, no-unnecessary-effects, review-commit-hygiene, review-pr-size, review-report-format, review-secret-scanning; plus cdk-construct-conventions, cdk-custom-resources, cdk-iam-least-privilege, cdk-stateful-resources when CDK files changed) to understand conventions, file organization, testing requirements, style guidelines, and architecture principles.

3. **Analyze each changed file** in `$CHANGED_FILES`:

   For a large diff, split this across one background subagent per package, all launched in
   the same message, and merge their findings. Where subagents aren't available (Cascade),
   work through the packages sequentially in a single pass.

   - Read the current version on the branch
   - Read the diff: `git diff $MERGE_BASE $TARGET -- $file`
   - Apply standards: code patterns, file structure, testing coverage, documentation
   - Identify violations, patterns, opportunities, risks

4. **Cross-reference the codebase**
   - Search for similar existing patterns and duplication opportunities
   - Verify consistency with existing code
   - Identify reusable components/functions

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
   - Write the full report to the **system temp dir** (outside the repo working tree),
     named after the branch with `/` replaced by `-`:

     ```bash
     REPORT_FILE="${TMPDIR:-/tmp}/branch-review-$(echo "$TARGET" | tr '/' '-').md"
     ```

     Write outside the repo, **not** to a repo folder: a repo `tmp/` is gitignored and
     Cascade's write tool silently skips gitignored paths, while any non-ignored repo
     folder ends up committed by accident. The system temp dir avoids both — it's writable
     by the normal write tool in Devin and Cascade and can never be committed.

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

The report file is the live state of the review, not a one-off snapshot. Touch it only
when a finding is resolved or invalidated — not after every edit, and not to record
verification runs:

- A finding that is fixed is **deleted**, not annotated. Renumber what is left and
  correct the count in the verdict line.
- A finding that turns out to be wrong is deleted, and the correction is stated in the
  chat reply.
- Re-check the rest of the file for entries the fix made stale (verification commands
  that now pass, "pre-existing" notes that no longer hold).

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
