---
name: prefer-router-links
description: Prefer react-router Link/NavLink for user-clickable navigation; reserve useNavigate for imperative navigation only, in Harbour frontend
triggers:
  - model
  - user
---

# Prefer Link/NavLink over useNavigate

Anything a user clicks to go somewhere is a link and must render a real anchor via `Link`/`NavLink`. Reaching for `useNavigate` in an `onClick` throws away everything the browser gives you for free: a real `href`, middle-click / cmd-click to open in a new tab, right-click "open in new tab", `Ctrl/Cmd`-click, keyboard focus, and correct screen-reader semantics.

## Rule

- **User-clickable navigation → `Link` or `NavLink`.** Nav items, buttons that go to a route, table-row "view" actions, breadcrumbs, menu entries.
- **`NavLink` when the element reflects active state** (sidebar/tabs). It applies an `.active` class and `aria-current="page"` automatically — delete manual `pathname === x` / `startsWith` logic and any `match` field.
- **`useNavigate` only for imperative navigation** that cannot be a link: after a form submit, an async callback (`onSuccess`), a redirect, or a programmatic decision. It never belongs in a plain click handler.

## Examples

```tsx
// BAD — imperative navigation for something the user clicks
<ButtonBase onClick={() => navigate(item.to)}>{label}</ButtonBase>

// GOOD — a real anchor
<ButtonBase component={NavLink} to={item.to}>{label}</ButtonBase>
```

```tsx
// GOOD — useNavigate is correct here (post-async, not a click target)
createExecution.mutate(payload, {
  onSuccess: (execution) =>
    navigate(`${routes.harbourNext}/executions/${execution.uuid}`),
});
```

## MUI + active styling

- Render MUI components as the link with `component={NavLink}` / `component={Link}` and pass `to`.
- Style the active state with the `&.active` selector inside the component's `sx` (theme palette only — no hardcoded colours), rather than toggling a separate `sx.active` from a computed boolean.
- `NavLink` matches the path _and its descendants_ by default; add `end` for exact-only matching.

## Why LLMs get this wrong

`useNavigate` is a one-liner to drop into an `onClick`, so it looks convenient. But convenience at author-time costs the user real browser behaviour and accessibility. Default to a link; only fall back to `useNavigate` when there is genuinely nothing to click.
