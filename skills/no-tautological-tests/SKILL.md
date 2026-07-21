---
name: no-tautological-tests
description: Do not add tests that exercise only code you wrote to satisfy them. A test must drive the real dependency/code path that the change affects. Use when writing or reviewing tests, especially bug-fix tests.
---

# No tautological tests

A test that only calls a helper you invented to make it pass proves nothing — it
just adds CI time. Every test must exercise the real behaviour it claims to cover.

## The rule

- A bug-fix test MUST reproduce the bug through the **same code path and
  dependencies** as production. If the bug comes from `@rjsf`, `@tanstack`, MUI,
  the router, etc., the test must render/run through that library — not a stand-in.
- If you introduce a helper as part of the fix, do not write a unit test that
  merely asserts the helper does what its body literally says. That is circular.
- Prefer one integration test at the real boundary over several isolated
  micro-tests that bypass the dependency.

## Litmus checks (all must be true)

1. **Would it fail before the fix?** Write it, run it, watch it fail for the real
   reason (the actual error/behaviour), then fix. If it passes before the fix, it
   is worthless.
2. **Does it import the real dependency the bug lives in?** If the bug is in
   `@rjsf` default-form-state, the test renders a real `Form`. A test that never
   imports the culprit cannot cover it.
3. **Does it assert observable behaviour** (rendered DOM, submitted payload,
   validation message) rather than the internals of a helper you just wrote?
4. **Does it add signal, not just runtime?** If an existing test already covers
   the path, extend/reuse it instead of adding a near-duplicate that lengthens CI.

## Anti-pattern

```ts
// BAD: circular. Tests only the function written to pass it; never touches @rjsf.
import { stripNulls } from "./stripNulls";
expect(stripNulls({ a: [null] })).toEqual({ a: [] });
```

## Correct

```ts
// GOOD: drives the real @rjsf render that produced the bad data, asserts the
// user-visible result. Fails before the fix for the real reason.
render(<Form formSchema={schemaWithRequiredMinItemsTable} onSubmit={vi.fn()} />, {
  wrapper: TestProviders,
});
await userEvent.click(screen.getByRole('button', { name: /submit/i }));
expect(await screen.findByText('At least one item is required')).toBeInTheDocument();
```

Base new tests on existing sibling tests (same harness, providers, real data
shapes) rather than inventing an isolated one.
