---
name: frontend-component-structure
description: Component architecture and file structure — atomic hierarchy, colocated companion files (test, story, styles), no barrel index files, naming, reuse rules, 200-line cap. Use when reviewing or writing React components.
triggers:
  - model
  - user
---

# Component architecture and file structure

## Atomic hierarchy

- **Atoms** — basic building blocks (Button, Input, Typography, Icon)
- **Molecules** — combinations of atoms (SearchBox, FormField, CardHeader)
- **Templates** — complex UI sections and layouts (Header, Sidebar, DataTable)
- **Pages** — route-specific components with business logic

Each component lives in its own folder at its atomic level, with companion files
co-located:

```
components/
├── atoms/Button/{Button.tsx, Button.test.tsx, Button.stories.tsx, styles.ts}
├── molecules/SearchBox/{...same files}
├── templates/DataTable/{...same files}
└── pages/DashboardPage/{DashboardPage.tsx, DashboardPage.test.tsx, styles.ts}
```

## Companion files

1. `Component.tsx` — implementation
2. `Component.test.tsx` — unit tests (React Testing Library)
3. `Component.stories.tsx` — Storybook stories for all variants, only if Storybook is in use
4. `styles.ts` — where every style of the component lives (see `styling` skill). A component with no markup of its own has no `styles.ts`; the rule is that styles go nowhere else, not that the file must exist.

Companion files exist when their tooling exists.

## Rules

- **No barrel `index.ts`.** Never add a file whose only job is re-exporting. Import directly from `./Button/Button`.
- One component per file, single responsibility.
- Max 200 lines per file. Refactor by extracting subcomponents or hooks, not by relaxing the limit.
- No comments — code must be self-documenting.
- Explicit TypeScript prop types and return types.

## Naming

- Components: PascalCase (`UserCard`, `SearchBox`)
- Files: `ComponentName.tsx`, `.test.tsx`, `.stories.tsx`
- Folders: PascalCase matching the component
- Interfaces: PascalCase descriptive (`UserCardProps`, `ButtonVariant`)

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

Import order:

```typescript
import { useState, useEffect } from "react";
import { Box, Typography } from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { Button } from "~/components/atoms/Button/Button";
import { formatDate } from "~/utils/date";
import type { User } from "~/types/user";
import { styles } from "./styles";
```

## Reuse before building

1. Check the shared component library for an existing component.
2. Check existing feature components for similar patterns.
3. Extract to the shared library when a pattern is duplicated across features.

- Reuse when an existing component covers 80%+ of needs (add props).
- Extend with new optional props.
- Never copy-paste component code.

## Creation process

1. Create the folder at the correct atomic level
2. Implement with explicit prop types
3. Create `styles.ts` with theme-aware colors
4. Write unit tests
5. Create Storybook stories for all variants, where Storybook is in use
6. Verify in Storybook before integration

## Performance

- `React.memo` for expensive components
- Correct hook dependency arrays
- Lazy-load routes and heavy components (see `bundle-imports` skill)

## What to flag in review

- New `index.ts` files that only re-export
- Components without a colocated `.test.tsx`
- Components over 200 lines (suggest where to split)
- `../` relative imports
- Multiple components exported from a single `.tsx` file (each should have its own folder)
- A component placed at the wrong atomic level
- Copy-pasted component code that should have been reused or extended
