---
name: frontend-no-render-functions
description: If it returns JSX it is a component — no renderX() helpers, no styled() outside styles.ts. Use when writing or reviewing React components.
triggers:
  - model
  - user
---

# No Render Functions

A plain function that returns JSX looks like a shortcut and costs you everything React gives a component: no display name in devtools, no props type at the call site, no `memo`, no hooks, no story, no test in isolation. It also hides branching inside another component's body, so the file grows and the branches never get named.

## Rule

- **Returns JSX → it is a component.** PascalCase name, a props interface, its own file, rendered as `<StatusIcon status={…} />`. Never `renderStatusIcon(status)`.
- **No `render*` / `get*Element` / `*Node` helpers** returning `JSX.Element`, and no local `const icon = cond ? <A /> : <B />` where a component would do.
- **Lookup maps are fine, rendering through them is not.** Keep `Record<Key, ComponentType>` in the component's own file and let the component pick from it; don't export a function that hands a component back to callers for them to render.
- **`styled()` and `keyframes` live in `styles.ts`**, in the component's folder — never inline in a `.tsx`, never in a shared `.ts` module that isn't a `styles.ts`.
- **Forward `className`** on any component MUI may clone (`Chip` `icon`/`avatar`/`label`, `ListItem` slots). MUI injects its own class; dropping it silently kills the slot styling.

## Examples

```tsx
// BAD — function returning JSX, branches buried in the parent
function renderStatusIcon(status: FlowExecutionState): JSX.Element | undefined {
  if (SPINNING.has(status)) return <SpinningIcon />;
  if (status === "ATTENTION_REQUIRED") return <AlertIcon />;
  return undefined;
}

<Chip icon={renderStatusIcon(status)} />;
```

```tsx
// GOOD — a real component, testable and storyable on its own
export function StatusIcon({
  status,
  size,
  className,
}: Readonly<StatusIconProps>): JSX.Element {
  const Icon = STATUS_ICON[status] ?? CircleDashed;

  return <Icon size={size} className={className} />;
}

<Chip icon={<StatusIcon status={status} size={12} />} />;
```

```ts
// BAD — styled() in a plain module
// src/statusIcons.ts
export const SpinningIcon = styled(RefreshCw)({
  animation: `${spin} 2s linear infinite`,
});
```

```ts
// GOOD — src/statusIcons/styles.ts
export const SpinningIcon = styled(RefreshCw)({
  animation: `${spin} 2s linear infinite`,
});
```

## Checklist

- [ ] Does this function return JSX? Make it a component with a props type.
- [ ] Is there a `render*` helper left in the file? Extract it.
- [ ] Any `styled()` / `keyframes` outside a `styles.ts`? Move it.
- [ ] Does the component sit in a MUI slot that clones its child? Forward `className`.

