---
name: frontend-component-structure
description: Component file structure — colocated companion files (test, story, styles), no barrel index files, file size caps. Use when reviewing or writing React components.
---

# Component file structure

Each component lives in its own folder with companion files co-located:

```
Button/
├── Button.tsx
├── Button.test.tsx
├── Button.stories.tsx   (only if Storybook is in use)
└── styles.ts
```

## Rules

- **No barrel `index.ts`** that just re-exports — import directly from `./Button/Button`.
- Companion files exist when their tooling exists (don't add `.stories.tsx` to a project without Storybook).
- One component per file.
- Max ~150 lines per file. Refactor by extracting subcomponents or hooks, not by relaxing the limit.

## Imports

- **Never** `../` relative imports — use the project's path alias (typically `~/` or `@/`).
- Direct imports from source files, not from barrel exports.

```ts
// wrong
import { Button } from './Button';     // resolves via index.ts
import { useFoo } from '../../hooks';

// right
import { Button } from './Button/Button';
import { useFoo } from '~/hooks/useFoo';
```

## What to flag in review

- New `index.ts` files that only re-export
- Components without colocated `.test.tsx`
- Components over 150 lines (suggest where to split)
- `../` relative imports
- Multiple components exported from a single `.tsx` file (each should have its own folder)
