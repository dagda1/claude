# Task: content-based skill selection for branch-review

Repo: `~/claude` (skills/workflows repo, symlinked into projects by `install.sh`).
You have no other context. Everything you need is in this file and the repo.

## Current state

- `skills/*/SKILL.md` — ~28 skills, each with YAML frontmatter (`name`, `description`).
- `skills/skills-for-files.sh` — selects skills for a list of changed files by matching
  filename globs against `skills/skills-map.txt` (a central pattern → skills map).
- `workflows/branch-review.md` step 2 pipes changed files through that script.

## Problem

Filename globs guess. A file named `loginSchema.ts` gets the zod skill whether or not
it uses zod. Content is proof: the zod skill is relevant only to files that import zod.

## Required change

1. Each skill declares its own relevance in its frontmatter. Two new keys:

   ```yaml
   files: "*.ts|*.tsx"            # required. Extended-glob alternation on the path.
   match: "from ['\"]zod['\"]"    # optional. POSIX ERE grepped against file CONTENT.
   ```

   A skill applies to a file when the path matches `files` AND, if `match` is present,
   `grep -E` finds the pattern in the file. No `match` key = glob-only skill.

2. Rewrite `skills/skills-for-files.sh`:
   - Input: changed file paths as arguments or stdin (both, as now).
   - It reads the frontmatter of every `skills/*/SKILL.md` (skip `review-*` and
     `assistant-*` — the review workflow handles those itself).
   - Output modes as now: default = union of applicable skill names, sorted, one per
     line; `--per-file` = `path: skill skill ...` per input file.
   - File paths are resolved relative to the current working directory (the repo under
     review), NOT relative to the skills directory. A path that doesn't exist on disk
     falls back to glob-only matching (content can't be checked) — do not error.
   - Bash only. No jq, no node, no python. Frontmatter parsing may assume the keys sit
     on single lines between the `---` markers.

3. Add `files`/`match` to every skill. Suggested `match` values — verify each against
   the skill's actual content before applying, adjust where wrong:

   | skill | files | match |
   |---|---|---|
   | frontend-zod-validation | `*.ts\|*.tsx` | `from ['"]zod['"]` |
   | frontend-react-query | `*.ts\|*.tsx` | `@tanstack/react-query` |
   | frontend-mui-theming | `*.tsx\|*.ts` | `@mui/\|useTheme\|sx=` |
   | frontend-suspense | `*.tsx\|*.ts` | `Suspense\|useSuspenseQuery` |
   | frontend-prefer-router-links | `*.tsx` | `react-router\|<a ` |
   | frontend-routing | `*.tsx\|*.ts` | `react-router` |
   | frontend-api-calls | `*.ts\|*.tsx` | `fetch(\|axios\|@tanstack/react-query` |
   | frontend-react-typescript | `*.tsx` | — |
   | frontend-component-structure | `*.tsx` | — |
   | frontend-no-boolean-params | `*.ts\|*.tsx` | — |
   | frontend-testing | `*.test.ts\|*.test.tsx\|*.spec.ts\|*.spec.tsx` | — |
   | no-tautological-tests | `*.test.ts\|*.test.tsx\|*.spec.ts\|*.spec.tsx` | — |
   | code-test-colocation | `*.ts\|*.tsx` | — |
   | code-error-handling | `*.ts\|*.tsx` | — |
   | code-style-defaults | `*.ts\|*.tsx` | — |
   | code-trust-the-types | `*.ts\|*.tsx` | — |
   | cdk-* (all four) | `*.ts` | `aws-cdk-lib` |
   | pr-message | — skip: not file-scoped, leave untouched |

4. Delete `skills/skills-map.txt`.

5. Update `workflows/branch-review.md` step 2: remove the sentence describing
   `skills-map.txt`; describe the new mechanism in one sentence (each SKILL.md's
   `files`/`match` frontmatter decides relevance; the script prints the applicable
   set). Keep the existing command, fallback paragraph, and everything else unchanged.

## Acceptance criteria — all must pass before you finish

Create fixtures in a temp directory (never inside the repo), then run the script
against them from that directory:

1. A `.ts` file importing zod → output includes `frontend-zod-validation`.
2. The same file without the zod import → output excludes it.
3. A `.ts` file containing `aws-cdk-lib` → the four `cdk-*` skills load; frontend
   skills don't.
4. A `.test.tsx` file → `no-tautological-tests` and `frontend-testing` load.
5. A path that doesn't exist on disk → script still returns its glob-only skills and
   exits 0.
6. Empty input → empty output, exit 0.
7. Every non-skipped SKILL.md has a `files` key — script prints a warning naming any
   that don't.
8. `grep -rn "skills-map" workflows/ skills/` returns nothing.

## Do not

- Do not touch skill bodies below the frontmatter.
- Do not change how `review-*` or `assistant-*` skills are handled.
- Do not add dependencies, colors, emoji, or explanatory comments in the script beyond
  a short header.
- Do not commit; leave changes for the user to review with `git diff`.
