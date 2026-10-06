---
name: implement
description: Implement a piece of work from a spec or checklist. Constraints are defined before any code is written, and every checklist item ends in a command. Use for /implement or any multi-step build task.
disable-model-invocation: true
---

# Implement

Implement the work in the spec the user points at.

## Before any code

1. Read the spec. If there is no spec file, write one from the user's request
   and stop for approval: a numbered checklist where every item names the
   command that proves it done (a test file, tsc, a curl). An item with no
   command is not ready to build.
2. Agree the seams with the user per the `tdd` skill: which public boundaries
   get tests. No test at an unconfirmed seam.
3. Run `.claude/skills/skills-for-files.sh` on the files you expect to touch
   and read the skills it names.

## During the pass

- Work the checklist in order. One item at a time.
- `/tdd` at the agreed seams: failing test first, then code.
- After each item: run that item's command, then `tsc --noEmit`, the touched
  test files, and jscpd over the files changed so far. Do not start the next
  item on a red command or a new clone.
- Mark each item done in the spec file as you go. The file is the state;
  a restarted session resumes from it.
- Search before creating any function. Name what you searched in the commit.

## After the pass

- Full test suite once.
- Commit per item or per coherent group; lint-staged gates each commit.
- Run `/branch-review`. Report its verdict and the report path, then stop.
