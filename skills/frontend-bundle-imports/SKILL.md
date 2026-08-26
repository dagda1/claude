---
name: frontend-bundle-imports
description: Lazy-route code-splitting and package barrel import boundaries — import from the package barrel, no per-component subpath exports, side-effect modules get their own subpath
triggers:
  - model
  - user
---

# Bundle & Import Boundaries

Rollup/rolldown tree-shakes a package barrel, so importing a component from `@acme/flow/flow-diagram` does **not** pull the whole package into the chunk. Don't add machinery to avoid that.

## Rules

- **Import from the package barrel by default.** One `exports` entry per package (plus its dev alias) is enough for components, hooks and types.
- **Don't add a subpath export per component.** Each one costs an `exports` entry, two dev aliases in the app `vite.config`, a `default` export, and a hard-coded `dist` path — for no chunking benefit. Under `CI=true` the dev aliases are off and everything resolves through `dist` anyway, so extra subpaths only add more paths that must exist.
- **Side-effect modules get their own subpath.** Anything imported for its effect rather than its value — `initializeLocales` and friends — can't be tree-shaken out, so expose it separately (`@acme/flow/i18n`) and never re-export it from the barrel.
- **A whole lazy page may have its own subpath** when it is the route's entry point and has a `default` export (`@acme/flow/FlowPage`). That's a readability convention, not a bundling requirement — the barrel would split correctly too.

```ts
// GOOD — barrel import, tree-shaken
import { StatusChip, FlowTabs } from "@acme/flow/flow-diagram";

// GOOD — side-effect module, own subpath
import { initializeLocales } from "@acme/flow/i18n";

// BAD — a subpath invented for one small component
const OverviewTab = lazy(() => import("@acme/flow/OverviewTab"));
```

## Lazy routes

Route components are still `lazy()`, so each route lands in its own chunk. What they import from is irrelevant to that — a barrel import inside a `lazy()` splits the same as a subpath.

**Review check:** flag any new per-component `exports` entry or dev alias, and any barrel re-export of a side-effect module.
