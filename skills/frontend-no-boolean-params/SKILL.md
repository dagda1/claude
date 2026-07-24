---
name: no-boolean-params
description: Avoid cryptic boolean parameters — prefer string-literal union types for options that affect behaviour or styling in Harbour frontend
triggers:
  - model
  - user
---

# No Cryptic Boolean Parameters

Boolean arguments are unreadable at the call site — `createWidgets(true)` tells the reader nothing. Prefer a string-literal union that is self-documenting.

## Rule

- **No positional boolean flags** on functions, factories, or component props when the value selects a mode/variant/theme.
- **Use a named string-literal union** whose members describe the choice.
- Applies to factory functions (`createX`), hooks, and component props alike.

## Examples

```typescript
// BAD — what does `true` mean?
export function createWidgets(useNextPalette: boolean): RegistryWidgetsType { ... }
createWidgets(true);

// GOOD — self-documenting at the call site
export type FormPalette = 'v1' | 'v2';
export function createWidgets(palette: FormPalette): RegistryWidgetsType { ... }
createWidgets('v2');
```

```typescript
// BAD
<Button large />
<Modal dismissible={false} />

// GOOD
<Button size="lg" />
<Modal dismiss="none" />
```

## When a boolean is fine

- The prop is a genuine binary state that reads naturally: `disabled`, `hidden`, `loading`, `required`, `open`.
- Rule of thumb: if you'd have to look up what `true` means, it should be a union.

## Naming

- Union members are short, lowercase string literals (`'v1' | 'v2'`, `'sm' | 'md' | 'lg'`).
- Export the union type next to its consumer so callers can reference it.
- Default the parameter to the most common member rather than relying on `false`.
