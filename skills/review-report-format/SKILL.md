---
name: review-report-format
description: Format rules for written branch / PR reviews — sequential numbering, Where-to-Comment table, mandatory positives, paragraph-style findings. Use when producing a written review report.
---

# Review report format

## Verdict scale

| Status | Criteria | Action |
|--------|----------|--------|
| **APPROVE** | Follows standards, no blocking issues | Merge |
| **NEEDS_WORK** | Minor issues, mostly compliant | Fix before merge |
| **BLOCKING** | Critical violations or missing requirements | Fix required |

## Findings

- **Number sequentially across all severities** (1, 2, 3...). The same number is used in the finding heading, the "Where to Comment" table, and the Action Items.
- **Every finding has a `> Where to comment:` blockquote** immediately after the heading — exact file path + line(s) + short description of the location, so the reviewer can post PR comments without re-reading the diff.
- **Findings use paragraph style**, not tables. Header → prose explanation → code-block fix.
- **High-severity items include a "What breaks" sentence** stating the failure mode and conditions.

## Positives are mandatory

A review that's purely a list of problems demoralises the author. Aim for **3–5 specific, concrete positives** — reference actual code decisions, not generic praise.

**Useful:** "Migrated bootstrap user creation to a single SQL file shared by Docker init and the AWS Lambda — eliminates drift between local and prod."

**Useless (don't write):** "Code is well-structured." / "Good use of TypeScript." / "Tests are comprehensive."

Place the Positives section **after findings, before** the "Where to Comment" table.

## Where to Comment table is mandatory

A consolidated quick-reference table covering **every** finding (not just high-severity), so the reviewer can post all comments in one pass.

| # | Severity | File | Line(s) | What to say |
|---|----------|------|---------|-------------|
| 1 | High | `file.ext` | N | [1-2 sentence summary of finding + fix] |

Use `(general)` for the line column when a comment applies to the file as a whole.

## Action Items

Three sections — `Required (blocking merge)`, `Recommended`, `Consider`. Each item is one sentence with a file reference: `(file.ext:N)`.

## Omit empty sections

No "High" heading if there are no high findings. No empty "Recommended" list if everything is required.

## Review principles

- Focus on **the diff**, not entire files.
- Maximize **parallelism** — independent checks run concurrently.
- Apply standards **pragmatically** — not every rule applies to every change.
- Recommendations must be **actionable** — concrete fix examples, not "consider improving X".
- Skip deep analysis on trivial changes (renames, formatting, imports).
