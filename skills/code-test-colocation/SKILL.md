---
name: code-test-colocation
description: Test files live next to source — `foo.ts` → `foo.test.ts`, `Bar.tsx` → `Bar.test.tsx`. No separate `test/` directories. Use when adding tests or reviewing test placement.
---

# Test colocation

Tests live next to the code they test, not in a separate top-level `test/` or `__tests__/` directory.

```
src/
├── matchData.ts
├── matchData.test.ts          ← right here
├── components/
│   └── MatchCard/
│       ├── MatchCard.tsx
│       └── MatchCard.test.tsx ← right here
```

## Rules

- `foo.ts` → `foo.test.ts` (same directory).
- `Bar.tsx` → `Bar.test.tsx` (same directory).
- No separate `test/`, `tests/`, `__tests__/` directories.
- Test config (Vitest, Jest) lives at repo root and discovers tests by pattern.

## Why

- One folder = one unit. Easier to see what's tested and what isn't.
- Moving a file moves its tests automatically.
- No mental tax mapping `src/foo/bar/baz.ts` → `tests/foo/bar/baz.test.ts`.

## What to flag in review

- New test files placed in a `test/` or `__tests__/` directory.
- Source file added without a sibling `.test.*` file (when one is expected).
- Test files that import via `../../../src/...` instead of `./...` — usually means they're not colocated.
