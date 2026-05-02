---
description: Comprehensive branch review against project standards. Writes report to ~/code/pr/Reviews/<branch>.md.
argument-hint: [branch] [base]
allowed-tools: Bash, Read, Grep, Glob
---

# Branch Review

Review the current (or specified) branch against project standards. Write a detailed report to `~/code/pr/Reviews/<branch>.md`.

**Arguments:**
- `$1` — branch to review (default: current branch)
- `$2` — base branch (default: `main`)

## Steps

### 1. Setup and gather context

Run these commands and capture the output:

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

### 2. Detect project areas and classify changes

A single branch may touch multiple areas. Classify all changed files:

| Signal | Area | Standards to apply |
|--------|------|--------------------|
| `*.tsx`, `*.ts` in `apps/frontend/` | **Frontend (React/MUI)** | CLAUDE.md frontend rules, no inline `sx`, no hardcoded colors, `Readonly<Props>`, explicit return types |
| `apps/frontend/**/*.test.tsx` | **Frontend tests** | Test through real component tree, assert what user sees, real data |
| `packages/api/**/*.py` | **API (FastAPI)** | Type hints, error context, no swallowed exceptions |
| `packages/ml/**/*.py` (incl. `alembic/`) | **ML / migrations** | Reproducibility, no future-leakage in features, migration safety |
| `packages/deploy/**/*.py` | **CDK (Python)** | Construct boundaries, IAM least-privilege, tagging, removal policies |
| `packages/db-bootstrap/**` | **DB bootstrap** | Idempotent SQL, role separation (master/migrator/app) |
| `*.Dockerfile`, `docker-compose.yml` | **Containers** | Layer caching, no secrets baked in |
| `.github/workflows/*.yml` | **CI/CD** | Pinned action versions, least-privilege tokens, no secret leakage |

### 3. Load project standards and skills

Always load (read in parallel):
- `CLAUDE.md` (project rules — DRY, no comments, error context, defensive programming bans, etc.)
- `~/.claude/rules/engineering-principles.md` (cognitive patterns: blast radius, boring by default, reversibility)
- All `review-*` skills from `.claude/skills/`:
  - `review-pr-size/SKILL.md`
  - `review-commit-hygiene/SKILL.md`
  - `review-secret-scanning/SKILL.md`
  - `review-report-format/SKILL.md`

Conditionally load based on what changed (read in parallel with the above):
- Frontend files (`*.tsx`, `*.ts` in `apps/frontend/`) → load relevant `frontend-*` skills:
  - `frontend-react-typescript/SKILL.md` (always for `.tsx` / `.ts`)
  - `frontend-mui-theming/SKILL.md` (if any MUI imports / `styles.ts` files changed)
  - `frontend-component-structure/SKILL.md` (if components added or moved)
  - `frontend-zod-validation/SKILL.md` (if API clients / parsers changed)
  - `frontend-react-query/SKILL.md` (only if `@tanstack/react-query` is in the dependency tree)
  - `frontend-testing/SKILL.md` (if any `*.test.tsx` / `*.test.ts` changed)

For changed files, also read existing similar files in the repo for consistency reference (e.g. if a new CDK construct landed, read 1-2 existing constructs for naming/tagging patterns).

### 4. Parallel analysis

For each area touched, run independent checks concurrently.

**Frontend (React/MUI):** apply the loaded `frontend-*` skills as checklists against the diff. Each skill has a "What to flag in review" section — work through it for each changed file.

**API / ML (Python):**
- Errors propagate with context — no bare `except:`, no swallowed exceptions
- Type hints on function signatures
- Tests cover behavior, not internals
- For ML: features use only pre-match data (no leakage)
- For migrations: safe under concurrent writes, reversible

**CDK:**
- Constructs are reusable — props interfaces explicit
- IAM least privilege — flag any `*` actions or resources without justification
- Stateful resources have explicit removal policies
- Tagging consistent with existing constructs
- No hardcoded account IDs / region values that should be config-driven
- New CustomResource `properties` bumped if behavior changed (so it re-runs)

**Containers:**
- No secrets in image layers
- Multi-stage where appropriate to slim final image
- `.dockerignore` covers node_modules, .venv, cdk.out

**CI/CD:**
- GitHub Actions pinned by SHA or tag (not `@main`)
- `permissions:` block uses minimum needed
- `GITHUB_TOKEN` write scopes only when justified

### 5. Cross-reference checks

- Apply `review-pr-size` (size caps) and `review-secret-scanning` (run the grep, investigate matches).
- Search for duplicated patterns across changed files and existing codebase (could a new util collapse to an existing one?).
- Check `pnpm.lock` / `uv.lock` deltas correspond to deliberate dep changes.

### 6. Commit quality scan

Apply `review-commit-hygiene` against `git log --oneline "$MERGE_BASE..$TARGET"`.

### 7. Identify positives

Apply `review-report-format`'s positives guidance — 3–5 specific, concrete positives referencing actual code decisions.

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

[2-3 sentence summary. Lead with what the branch does well. Then state blocking issues count and nature.]

---

## Diff Stats

```
[git diff --stat output]
```

**Key areas:**
- `path/to/area/` — [Brief description of what changed and why it matters]

---

## Findings

Number findings sequentially (1, 2, 3...) across all severities so they can be referenced in the "Where to Comment" table.

### High

**1. <Short title>**

> **Where to comment:** `file.ext`, line N (description of location)

[2-4 sentence explanation. What breaks, under what conditions.]

**Fix:**

```language
[concrete code fix]
```

---

### Medium

**2. <Title>**

> **Where to comment:** `file.ext`, line N

[Explanation. For medium items, a question asking the author to confirm intent is also appropriate.]

---

### Low / Nits

**3. <Title>**

> **Where to comment:** `file.ext`, line N

[1-2 sentences.]

---

## Positives

- **<Title>.** [Why this is good and what it enables — reference actual code.]
- ...

(3-5 minimum.)

---

## Where to Comment in the PR

| # | Severity | File | Line(s) | What to say |
|---|----------|------|---------|-------------|
| 1 | High | `file.ext` | N | [1-2 sentence summary of finding + fix] |
| ... | ... | ... | ... | ... |

(Include ALL findings, not just high.)

---

## Action Items

### Required (blocking merge)
1. **<Title>.** [One sentence + file ref.] (`file.ext:N`)

### Recommended
1. ...

### Consider
1. ...

---

_Generated by /branch-review_
```

**Report rules:**
- Findings numbered sequentially across all severities — same number used in heading, "Where to Comment" table, and Action Items.
- Every finding has a `> Where to comment:` blockquote immediately after the heading.
- Findings use paragraph style, not tables. Header → prose → code block fix.
- "Diff Stats" includes a "Key areas" bullet list.
- Positives section is mandatory and placed before "Where to Comment".
- "Where to Comment" table is mandatory — covers every finding.
- Omit empty severity sections (no "High" heading if there are no high findings).

### 9. Print summary and clean up

- Print verdict + key findings to console
- Print: `Review written to <path>`
- Run `git checkout "$ORIGINAL"` to return to the branch you started on

## Assessment scale

| Status | Criteria | Action |
|--------|----------|--------|
| **APPROVE** | Follows all standards, no blocking issues | Merge |
| **NEEDS_WORK** | Minor issues, mostly compliant | Fix before merge |
| **BLOCKING** | Critical violations or missing requirements | Fix required |

## Review principles

- Focus on **the diff**, not entire files — only review what changed.
- Maximize **parallelism** — independent checks run concurrently.
- Apply standards **pragmatically** — not every rule applies to every change.
- Recommendations must be **actionable** — concrete fix examples, not "consider improving X".
- **Celebrate what's done well** — positives are mandatory.
- **Tell the reviewer where to comment** — every finding has exact file + line.
- Skip deep analysis on trivial changes (renames, formatting, imports).
