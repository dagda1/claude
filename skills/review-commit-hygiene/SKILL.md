---
name: review-commit-hygiene
description: Commit message and history hygiene checks for reviews — wip/fixup commits, mixed concerns, mega-commits. Use when reviewing the commit log of a branch.
---

# Commit hygiene

A clean commit history makes `git bisect` and `git revert` possible. A messy one makes both useless.

## Run

```bash
git log --oneline "$MERGE_BASE..$TARGET"
```

## Flag

- `wip`, `fixup`, `temp`, `oops`, `asdf`, `.` commit messages — should be squashed before merge.
- Commits that mix unrelated changes (e.g. "fix bug + refactor styles + add feature").
- Non-trivial commits with no body explaining *why* (subject alone is usually not enough for a sizable change).
- A single mega-commit covering 50+ files — destroys bisectability.
- Merge commits from `main` into the feature branch where a rebase would have been cleaner (project-dependent — only flag if the project uses linear history).

## Don't flag

- Short subjects on small, obviously-self-contained commits.
- Repeated subject prefixes (`chore:`, `feat:`, `fix:`) when the project uses Conventional Commits.
