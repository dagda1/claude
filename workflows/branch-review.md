---
description: Comprehensive branch review against project standards. Writes report to ~/code/pr/Reviews/<branch>.md, then stops and proposes fixes for the user to approve before any are applied.
argument-hint: [branch] [base]
allowed-tools: Bash, Read, Grep, Glob, Task
---

# Branch Review

Review the current (or specified) branch against project standards. Write a report to `~/code/pr/Reviews/<branch>.md`.

Arguments: `$1` — branch to review (default: current branch). `$2` — base branch (default: `main`).

**Dispatch (Claude Code):** run steps 1–9 in a fresh context — invoke the `reviewer` subagent via Task with branch, base and report path, then continue from step 10 with its verdict. Never review inline: the context that wrote the code approves its own work. Run steps 1–9 inline only where subagents are unavailable (e.g. Devin).

## Steps

### 1. Setup and gather context

```bash
ORIGINAL=$(git branch --show-current)
TARGET="${1:-$ORIGINAL}"
BASE="${2:-main}"
git fetch origin "$BASE" "$TARGET" 2>/dev/null || true
git checkout "$TARGET" 2>/dev/null || true
MERGE_BASE=$(git merge-base "origin/$BASE" "$TARGET")
SAFE_BRANCH=$(echo "$TARGET" | sed 's|/|--|g')
REVIEW_DIR="$HOME/code/pr/Reviews"
REVIEW_FILE="$REVIEW_DIR/${SAFE_BRANCH}.md"
mkdir -p "$REVIEW_DIR"

REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')
PR_LINK="${REPO_URL}/compare/${BASE}...${TARGET}"
REPO_NAME=$(basename "$REPO_URL")

CHANGED_FILES=$(git diff --name-only "$MERGE_BASE" "$TARGET" | grep -v "node_modules" | grep -v "package-lock" | grep -v "pnpm-lock" | grep -v "uv.lock")
git diff --stat "$MERGE_BASE" "$TARGET"
git log --oneline "$MERGE_BASE..$TARGET"
DIFF_OUTPUT=$(git diff "$MERGE_BASE" "$TARGET" --no-color)
```

### 2. Classify changed files by area

A branch may touch multiple areas:

| Signal | Area |
|--------|------|
| `*.tsx`, `*.ts` in `apps/frontend/` | Frontend (React/MUI) — CLAUDE.md frontend rules, no inline `sx`, no hardcoded colors, `Readonly<Props>`, explicit return types |
| Data-fetching hooks (`useQuery`, `useMutation`, `urql`, `xior`, `fetch`) | API calls — `frontend-api-calls` skill: URLs from the shared `urls` constants module, no `fetch`, every response Zod-parsed |
| `package.json` `exports`, `vite.config.*` aliases, `lazy(() => import(...))` | Bundle & imports — `frontend-bundle-imports` skill: barrel imports by default, no per-component subpath exports, side-effect modules on their own subpath |
| New or moved files under `components/` | Component architecture — `frontend-component-structure` skill: correct atomic level, companion files present, no barrel `index.ts`, naming, reuse before building |
| New or changed function signatures and component props | API ergonomics — `frontend-no-boolean-params` skill: mode/variant options are string-literal unions, not booleans |
| Any code handling optional values (`??`, `\|\|`, ternary defaults) | Fallbacks — `code-no-defensive-fallbacks` skill: one owner per fallback, no `?? ''`, no default invented to satisfy a type |
| `*.tsx` with functions returning JSX, or `styled()` / `keyframes` calls | Render functions — `frontend-no-render-functions` skill: JSX-returning functions are components, `styled()` belongs in `styles.ts`, forward `className` in MUI slots |
| `apps/frontend/**/*.test.tsx` | Frontend tests — test through real component tree, assert what user sees, real data |
| `packages/api/**/*.py` | API (FastAPI) — type hints, error context, no swallowed exceptions |
| `packages/ml/**/*.py` (incl. `alembic/`) | ML / migrations — reproducibility, no future-leakage in features, migration safety |
| `packages/deploy/**/*.py` | CDK — construct boundaries, IAM least-privilege, tagging, removal policies |
| `packages/db-bootstrap/**` | DB bootstrap — idempotent SQL, role separation (master/migrator/app) |
| `*.Dockerfile`, `docker-compose.yml` | Containers — layer caching, no secrets baked in |
| `.github/workflows/*.yml` | CI/CD — pinned actions, least-privilege tokens, no secret leakage |

### 3. Load project standards and skills

Always load (read in parallel):
- `CLAUDE.md` (project rules)
- `~/.claude/rules/engineering-principles.md`
- All `review-*` skills, discovered by glob so new ones are never missed: `ls .claude/skills/review-*/SKILL.md`
- All `code-*` skills (language-agnostic code standards), same glob approach: `ls .claude/skills/code-*/SKILL.md`

Conditionally, glob the family and read all matches:
- Frontend files changed → `ls .claude/skills/frontend-*/SKILL.md`, then apply each only where its subject matches the diff (MUI theming skill only if styling changed, react-query skill only if `@tanstack/react-query` in the tree, `frontend-api-calls` only if data-fetching hooks or HTTP calls changed, `frontend-no-boolean-params` only if function signatures or component props changed, `frontend-no-render-functions` only if `*.tsx` or `styles.ts` changed, `frontend-bundle-imports` only if package `exports`, bundler config or `lazy()` route imports changed, testing skill only if `*.test.ts*` changed).
- `useEffect` added or changed → read `.claude/skills/no-unnecessary-effects/SKILL.md` (no family prefix, so no glob finds it).
- CDK files changed (`packages/deploy/**`, `*.stack.ts`, imports of `aws-cdk-lib`) → `ls .claude/skills/cdk-*/SKILL.md`, then apply each only where relevant (IAM skill if `grant*`/policy/role changes, stateful-resources if RDS/S3/DynamoDB/EFS changed, custom-resources if `CustomResource`/`Provider`/handler Lambda changed).

For changed files, also read 1-2 existing similar files in the repo as consistency reference (naming/tagging patterns).

### 4. Parallel analysis

For each area touched, run independent checks concurrently.

- **Frontend / CDK:** apply the loaded skills as checklists — work through each skill's "What to flag in review" section per changed file.
- **API / ML (Python):** errors propagate with context (no bare `except:`, no swallowed exceptions); type hints on signatures; tests cover behavior not internals; ML features use only pre-match data (no leakage); migrations safe under concurrent writes and reversible.
- **Containers:** no secrets in image layers; multi-stage where appropriate; `.dockerignore` covers node_modules, .venv, cdk.out.
- **CI/CD:** actions pinned by SHA or tag (not `@main`); `permissions:` block minimal; `GITHUB_TOKEN` write scopes only when justified.

### 5. Cross-reference checks

- Apply `review-pr-size` and `review-secret-scanning` (run the grep, investigate matches).
- Search for duplicated patterns across changed files and existing codebase (could new code collapse into an existing util?).
- Check `pnpm.lock` / `uv.lock` deltas correspond to deliberate dep changes.

### 6. Commit quality scan

Apply `review-commit-hygiene` against `git log --oneline "$MERGE_BASE..$TARGET"`.

### 6a. Shortcut and architectural-drift scan

Check whether the diff is the shortcut version of work that was supposed to follow a documented design. **HIGH severity** by default.

**Step 1 — find relevant planning docs.**

```bash
ls plans/*.md 2>/dev/null
git log --since="30 days ago" --name-only "$MERGE_BASE..$TARGET" -- plans/ | sort -u
git log --oneline "$MERGE_BASE..$TARGET" | grep -iE 'plan|design|spec|rfc'
```

Read each `plans/*.md` referenced or recently modified; note its checklist items.

**Step 2 — verify the diff implements the documented approach.** Does the diff tick the checklist items it claims to address? If the plan says "do X by mechanism Y", did the diff use Y or a simpler Z with similar-looking output? Are plan-mandated gate tests present and passing? Does the diff reintroduce a pattern the plan forbids? A diff that produces working output but bypasses the prescribed structure is a shortcut, even if functional — flag as HIGH.

**Step 3 — anti-pattern scan against `DIFF_OUTPUT`:**

| Pattern | Grep for | Severity |
|---------|----------|----------|
| Test disabled/skipped | `xit\(`, `it\.skip`, `describe\.skip`, `pytest\.mark\.skip`, `@unittest\.skip`, commented-out tests | HIGH if test enforces a documented invariant |
| Type-system bypass | `as unknown as`, `: any`, `# type: ignore`, `// @ts-ignore`, `// @ts-expect-error` without justification | HIGH |
| Error-swallowing | Python bare `except: pass`, empty JS catch blocks | MEDIUM (HIGH if error previously propagated) |
| Null-handling masking a real error | `?.`, `??`, `\|\|` — do NOT auto-flag (normal TS). Flag per `code-no-defensive-fallbacks`: a default that hides a value that should never be missing, `?? ''`, a second default where the callee already handles the empty case, or a coalesce added only to satisfy a type | MEDIUM (HIGH for `?? ''`) |
| Parallel implementation of existing capability | New symbol whose name overlaps an existing one (`grep -i` it against the repo) | HIGH if both produce final answers; else MEDIUM |
| Reintroduced forbidden pattern | Patterns CLAUDE.md bans (e.g. banner-import hacks in CDK bundling) | MEDIUM (HIGH if explicitly banned) |
| Hardcoded secrets/magic values | `secret`, `password`, `token`, IPs, prod-looking URLs | HIGH |
| Inlined API URL | Endpoint path literals in hooks/components instead of the shared `urls` constants module; same URL string in more than one file; raw `fetch(` | MEDIUM (HIGH if the URL is duplicated) |
| Per-component subpath export | New `exports` entry or bundler dev alias for a single component; barrel re-export of a side-effect module | MEDIUM |
| Render function instead of a component | `function render[A-Z]`, `const render[A-Z]`, `get[A-Z]\w*Element`, or any local returning `JSX.Element`; `styled(` or `keyframes` outside a `styles.ts` | MEDIUM |
| Cryptic boolean parameter | New boolean function parameter or component prop that selects a mode/variant/theme (`use*`, `is*Mode`, `large`, `*Enabled`); a call site passing a bare `true`/`false` | MEDIUM |
| Component at the wrong atomic level, missing companions, or barrel-exported | New `components/**/*.tsx` with no sibling `.test.tsx`; a page-level component under `atoms/`/`molecules/`; a new `index.ts` that only re-exports; copy-pasted component code | MEDIUM (HIGH if the test is missing) |
| "While I'm here" scope creep | Files unrelated to commit message purpose; reformat mixed with logic | MEDIUM |
| Half-finished migration | New path added, old not removed; new fields added, call sites read old ones; old tests asserting opposite behavior still pass | HIGH |
| Disabled lint/type-check rule | New `// eslint-disable`, `# noqa`, `# pragma: no cover`, tsconfig/pyright exclusions | MEDIUM |
| Removed test without replacement | Test file/cases deleted with no equivalent added | HIGH |

**Step 4 — report.** Prefix these findings `[SHORTCUT]`. Each must quote the bypassed plan requirement (with path), show the diff's implementation, describe the prescribed one, and explain why the chosen path is a shortcut. If none found, add one positive: "**Followed the documented design.** [Plan] checklist items are all addressed, no anti-patterns detected."

### 7. Identify positives

Apply `review-report-format`'s positives guidance — 3–5 specific positives referencing actual code decisions.

### 8. Write the report

Write to `$REVIEW_FILE`:

```markdown
# Branch Review: <branch>

**Date:** <YYYY-MM-DD>
**PR:** [<repo>: <branch>](<compare URL>)
**Base:** <base>
**Files changed:** <n>
**Commits:** <n>

---

## Verdict: APPROVE | NEEDS_WORK | BLOCKING

[2-3 sentences. Lead with what the branch does well, then blocking issue count and nature.]

---

## Diff Stats

```
[git diff --stat output]
```

**Key areas:**
- `path/to/area/` — [what changed and why it matters]

---

## Findings

### High

**1. <Short title>**

> **Where to comment:** `file.ext`, line N

[2-4 sentences: what breaks, under what conditions.]

**Fix:**

```language
[concrete code fix]
```

### Medium

**2. <Title>**

> **Where to comment:** `file.ext`, line N

[Explanation; asking the author to confirm intent is fine here.]

### Low / Nits

**3. <Title>**

> **Where to comment:** `file.ext`, line N

[1-2 sentences.]

---

## Positives

- **<Title>.** [Why this is good — reference actual code.]

(3-5 minimum.)

---

## Where to Comment in the PR

| # | Severity | File | Line(s) | What to say |
|---|----------|------|---------|-------------|
| 1 | High | `file.ext` | N | [finding + fix in 1-2 sentences] |

---

## Action Items

### Required (blocking merge)
1. **<Title>.** [One sentence.] (`file.ext:N`)

### Recommended
### Consider

---

_Generated by /branch-review_
```

Report rules:
- Findings numbered sequentially across all severities; same number in heading, "Where to Comment" table, and Action Items.
- Every finding has a `> Where to comment:` blockquote with exact file + line.
- Findings are paragraph style (header → prose → code fix), not tables.
- Positives section is mandatory, before "Where to Comment"; "Where to Comment" table covers every finding.
- Omit empty severity sections.

### 9. Summary and cleanup

Print verdict + key findings and `Review written to <path>`, then `git checkout "$ORIGINAL"`.

### 10. Stop and propose fixes — wait for approval

If the verdict is `APPROVE`, report done and stop.

Otherwise **do not touch any files**. Present a short numbered list of the proposed fixes for every "Required (blocking merge)" and High-severity item in `$REVIEW_FILE`. Each proposed fix line must be:

`N. file:line — <the change> — conforms to: <skill/rule name>`

The `conforms to:` clause is mandatory and must name the specific loaded skill (`.claude/skills/*/SKILL.md`) or project rule (CLAUDE.md / engineering-principles.md) that the fix satisfies. Before proposing a fix, re-read the relevant skill's "What to flag in review" / standards section and make the fix match it — do not invent an ad-hoc fix. If a proposed change would violate any loaded skill (e.g. hardcoding a color to silence a lint, adding inline `sx`, skipping a companion test file), do not propose it: say which skill it conflicts with and leave the finding for the user to decide.

Then stop and wait for the user to approve. Do not apply, stage, or commit anything until the user explicitly OKs. The user may approve all, approve a subset (e.g. "do 1 and 3"), edit the list, or decline.

Only after approval, apply the approved fixes. Then re-check the staged changes against the same loaded skills: re-run the relevant skill checklists over `git diff --staged`, and if any staged change violates a skill, revert that change and report it rather than staging a skill-breaking fix. Finally `git add` and `git diff --staged` so the user can inspect, and stop again — let the user commit themselves. Never auto-loop into a re-review; if the user wants another pass, they re-run `/branch-review`.

## Assessment scale

**APPROVE** — follows all standards, no blocking issues. **NEEDS_WORK** — minor issues, fix before merge. **BLOCKING** — critical violations, fix required.

## Review principles

- Review **the diff**, not entire files; skip deep analysis on trivial changes (renames, formatting, imports).
- Maximize parallelism; apply standards pragmatically — not every rule applies to every change.
- Recommendations must be actionable — concrete fixes, not "consider improving X".
