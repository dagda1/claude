---
name: frontend-routing
description: React Router conventions — lazy-loaded top-level pages, central routes file, layout wrapper as route element with `Outlet`. Use when reviewing or writing routing code in a React Router project.
---

# Frontend routing

## Lazy-load top-level pages

```ts
import { lazy } from 'react';

const HomePage = lazy(() => import('~/pages/HomePage/HomePage'));
const MatchPage = lazy(() => import('~/pages/MatchPage/MatchPage'));
```

Use the path alias (`~/`), not relative imports.

## Routes live in a dedicated file

Don't scatter `<Route>` definitions across `App.tsx`, layouts, and feature folders. One central routes file.

```ts
// routes.tsx
export function AppRoutes(): JSX.Element {
  return (
    <Routes>
      <Route element={<Page />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/match/:id" element={<MatchPage />} />
      </Route>
    </Routes>
  );
}
```

## Layout wrapper as route `element`, pages render via `Outlet`

The `Page` (or `Layout`) component is a route-level `element`. Children render via `Outlet`.

```ts
// Page/Page.tsx
import { Outlet } from 'react-router';

export function Page(): JSX.Element {
  return (
    <Box sx={sx.shell}>
      <Header />
      <Box sx={sx.content}>
        <Outlet />
      </Box>
    </Box>
  );
}
```

## What to flag in review

- Top-level pages imported directly (not via `lazy(() => import(...))`).
- `<Route>` definitions added to `App.tsx` or scattered across feature folders instead of the central routes file.
- Layout / wrapper components rendered inside each page instead of as a route `element`.
- Relative imports (`../`) in route or page files instead of `~/`.
