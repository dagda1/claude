---
name: assistant-output-expectations
description: Output expectations for the assistant — keep diffs minimal, update related docs/tests when behavior changes, never add "Generated with Claude Code" attribution. Always relevant when producing code.
---

# Output expectations

## Minimal diffs

- Touch only what the task requires.
- No "while I'm here" reformats, renames, or refactors unless explicitly requested.
- If a refactor would help, flag it and ask — don't slip it in.

## Update related docs / tests

If you change behavior, update anything that describes it:

- Tests that assert the old behavior.
- README / docs that mention it.
- Type definitions that no longer match.
- Comments at integration points (if any exist).

## No attribution noise

- Never add "Generated with Claude Code" / "Co-authored by Claude" / similar to:
  - PR descriptions
  - Commit messages (unless explicitly requested)
  - File headers
  - Any code or documentation
