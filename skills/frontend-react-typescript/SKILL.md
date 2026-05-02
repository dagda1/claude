---
name: frontend-react-typescript
description: React + TypeScript import and typing conventions — JSX type imports, event types, return types, component declaration style, props extraction. Use when reviewing or writing React/TSX code.
---

# React + TypeScript conventions

## Imports

- **Never** `import type { JSX } from 'react'` — `JSX.Element` is globally available.
- **Never** use the `React.*` namespace for types. Import directly:

```ts
// wrong
const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {};

// right
import type { MouseEvent } from 'react';
const handleClick = (event: MouseEvent<HTMLButtonElement>) => {};
```

Same applies to `ChangeEvent`, `KeyboardEvent`, `FormEvent`, `SetStateAction`, `Dispatch`, `RefObject`, etc.

## Components

- Named function declarations with explicit `JSX.Element` return type.
- **Never** `React.FC` / `FunctionComponent` — they obscure the signature and add implicit children.
- **Never** arrow components: `const Foo = () => …`.
- **Never** return type `ReactElement` — use `JSX.Element`.

```ts
export function UserCard({ user }: Readonly<UserCardProps>): JSX.Element {
  return <div>{user.name}</div>;
}
```

## Props

- Extract to a named `interface`, never inline.
- Wrap in `Readonly<Props>`.
- Explicit return type on every exported hook and function — no exceptions.

## What to flag in review

- `React.FC<...>` or `FunctionComponent<...>`
- `const X = (...) => ...` for components
- `import type { JSX } from 'react'`
- `React.MouseEvent` (or any `React.*` type)
- Inline prop types: `function Foo({ x }: { x: string })`
- Missing return type on exported hook/component
