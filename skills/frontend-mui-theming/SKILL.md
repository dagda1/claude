---
name: frontend-mui-theming
description: Material-UI styling discipline — separate styles files, theme palette references, no hardcoded colors or pixels. Use when reviewing or writing MUI components.
---

# MUI theming discipline

## Separate styles file

- All styles in a `styles.ts` next to the component.
- Export name is **always** `sx` — never `styles`, `fooStyles`, etc.
- Type as `Record<string, SxProps<Theme>>`.
- **Never** inline `sx={{ ... }}` in JSX.

```ts
// styles.ts
import type { SxProps, Theme } from '@mui/material/styles';

export const sx: Record<string, SxProps<Theme>> = {
  card: {
    p: 2,
    backgroundColor: (theme) => theme.palette.background.paper,
    borderRadius: (theme) => theme.shape.borderRadius,
  },
};

// Component.tsx
import { sx } from './styles';
<Card sx={sx.card}>
```

## Colors

- Use `theme.palette.*` exclusively. Semantic colors: `error.main`, `success.main`, `warning.main`, `info.main`.
- **Never** `#fff`, `rgb(...)`, `rgba(...)`, named colors (`'red'`).
- For `sx` references, use either the function form `(theme) => theme.palette.x` or the string shorthand `'primary.main'`.

## Spacing

- Use `theme.spacing(n)` or shorthand (`p: 2`, `gap: 1.5`). The theme owns the rhythm.
- **No raw `px` for spacing.**

## What to flag in review

- Inline `sx={{ ... }}` props in JSX
- Hex codes, `rgb(`, `rgba(`, named colors in styles
- Pixel values for spacing/sizing where theme spacing would do
- Styles file exporting under a name other than `sx`
- Styles inline in the component file instead of in `styles.ts`
- `useTheme()` called only to read a palette value — the function-form `sx` already gets the theme
