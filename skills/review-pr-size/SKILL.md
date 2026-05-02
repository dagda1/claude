---
name: review-pr-size
description: PR size limits and feature-splitting guidance for reviews. Use when assessing whether a branch / PR is too large to review safely.
---

# PR size limits

Large PRs (100+ files) are hard to review, risky to merge, painful to revert. Flag any PR that exceeds these caps without a written justification.

| PR type | Max files | Notes |
|---------|-----------|-------|
| Bug fix | ~10 | Targeted change + regression test |
| Infrastructure / types | ~20 | New schemas, types, IaC modules |
| Components / features | ~30 | New components with tests + stories |
| Pages / wiring | ~50 | Page composition, route wiring |
| Refactors | ~50 | Renames, file moves, restructuring |

## Splitting large features

Split in dependency order so each PR is independently mergeable:

1. Types & schemas
2. API layer (clients, hooks, services)
3. Atoms / leaf components
4. Templates / composed components
5. Pages / route wiring
6. Polish, docs, feature flag flip

## What to flag in review

- File count exceeds cap for the PR type without justification in the description.
- A single PR mixing types + API + components + pages — should have been a stack.
- A PR claiming to be a "refactor" that also adds new behavior — split.
- A feature PR with no feature flag and >30 files of new behavior — high revert cost.
