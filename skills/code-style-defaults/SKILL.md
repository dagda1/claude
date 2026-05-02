---
name: code-style-defaults
description: Generic code style defaults — no comments, no single-character variables, braces on all if statements, blank lines between logical sections, prefer existing packages, no file extensions on imports, no `!` non-null assertion, no `as unknown as`. Use when writing or reviewing any code.
---

# Code style defaults

## No comments

- No inline comments (`//`, `/* */`, `#`).
- No JSDoc / docstrings on internal code.
- No `TODO` / `FIXME` comments — file an issue or fix it now.
- Code should be self-documenting through clear names and logical structure.

The only exception: a non-obvious *why* (a hidden constraint, subtle invariant, workaround for a specific bug). If removing the comment wouldn't confuse a future reader, don't write it.

## Naming

- Never single-character variables. `i`, `j`, `e`, `x` — all banned.
- Names describe the *purpose*, not the type.

```ts
// BAD
items.map((i) => i.id);
catch (e) { ... }

// GOOD
items.map((item) => item.id);
catch (error) { ... }
```

## Control flow

- Always use braces after `if`, `for`, `while`, etc. — even one-liners.

```ts
// BAD
if (loading) return null;

// GOOD
if (loading) {
  return null;
}
```

## Readability

- Add blank lines between logical sections within functions.
- Prefer small functions and descriptive names over comments.

## Imports

- No file extensions on imports.

```ts
// BAD
import x from './foo.js';
import y from './bar.ts';

// GOOD
import x from './foo';
import y from './bar';
```

## Forbidden TypeScript patterns

- Never `!` non-null assertion.
- Never `as unknown as T` double cast.

(See `code-trust-the-types` for the full reasoning.)

## Dependencies

- Prefer existing npm/pip packages over reimplementing functionality.
- Before writing a utility, check if a well-maintained package already does it.

## Scope

- Don't change unrelated files.
- Don't sneak in refactors, reformats, or "while I'm here" changes without flagging them.

## What to flag in review

- Any `//`, `/* */`, `#` comment that explains *what* the code does
- `TODO` / `FIXME` comments
- Single-character variable names
- `if (cond) doX();` without braces
- `import x from './foo.js'` (extension on a relative import)
- `!` non-null assertion
- `as unknown as` double cast
- Hand-rolled utility that duplicates a known npm package
- Diff touching files outside the scope of the stated task
