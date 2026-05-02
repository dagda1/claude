---
name: frontend-testing
description: React Testing Library discipline — render through real component tree, assert on rendered DOM, interact via userEvent not fireEvent, use real data shapes. Use when reviewing or writing React component tests.
---

# React Testing Library discipline

Test what the user sees and does, not internal wiring.

## Render through the real tree

- Render with the same providers the app uses (router, theme, query client).
- Don't isolate components with mock props that bypass the surrounding tree.

## Assert what the user sees

```ts
// wrong — internal wiring, proves nothing
expect(props.onChange).toHaveBeenCalledWith('Arsenal');

// right — what the user sees
expect(screen.getByRole('cell', { name: 'Arsenal' })).toBeInTheDocument();
```

## Interact like a user

```ts
// wrong
fireEvent.change(input, { target: { value: 'foo' } });

// right
const user = userEvent.setup();
await user.click(screen.getByRole('button', { name: 'Select' }));
const option = await screen.findByRole('option', { name: 'Arsenal' });
await user.click(option);
expect(screen.getByText('Arsenal')).toBeInTheDocument();
```

## Use real data shapes

API-shaped fixtures, not hand-crafted partials. If a component reads from a query, drive the test through that same query path.

## What to flag in review

- `fireEvent` instead of `userEvent` for interactions.
- `expect(handler).toHaveBeenCalled()` patterns instead of asserting on the rendered DOM.
- Hand-crafted partial fixtures where the real API shape is available.
- Component rendered in isolation when it normally lives inside providers.
- Missing `await` on `findBy*` / `userEvent` calls.
- Tests that just render and assert "renders without crashing" — adds no signal.
