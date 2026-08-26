---
name: suspense
description: Use React Suspense for data fetching so sections stream in independently instead of blocking on isLoading; skeletons are the fallback of choice, in Harbour frontend
triggers:
  - model
  - user
---

# React Suspense for data fetching

Don't gate a component behind `if (isLoading) return <Spinner />`. That blocks the whole subtree on one request, collapses layout to a centred spinner, and makes every consumer re-implement the loading branch. Fetch with Suspense so each section streams in on its own; the boundary's fallback is a skeleton that matches the final layout.

## Rule

- **Data fetching suspends.** REST: `useSuspenseQuery` from `@tanstack/react-query` (same query keys and invalidation rules as the `react-query` skill — suspense changes only how the pending state is surfaced). GraphQL: `context: { suspense: true }` with `urql` (see `api-calls` skill). No `isLoading` / `isPending` branch in the component.
- **A `<Suspense>` boundary owns the fallback**, placed at the layout unit that should show a placeholder — not at the app root, or the whole page flashes.
- **Push boundaries down to each independent section.** A page is not one loading unit — wrap each subcomponent that fetches its own data in its own boundary with its own skeleton, so each section streams in as its request resolves. A slow sidebar must never hold up a ready table. Never block the whole page on the slowest request.
- **The fallback is a skeleton, not a spinner.** It mirrors the real layout — same rough dimensions, same number of rows/cards — so nothing shifts when data arrives.
- **Spinners are for imperative actions only** — a button's inline busy state during a mutation, never for initial page/section load.

## Example

```tsx
// BAD — blocks the subtree, layout collapses to a centred spinner
function WorkItems() {
  const { data, isLoading } = useQuery({ queryKey: ["workItems"], queryFn });
  if (isLoading) return <Spinner />;
  return <WorkItemList items={data} />;
}

// GOOD — component assumes data exists; boundary owns the fallback
function WorkItems() {
  const { data } = useSuspenseQuery({ queryKey: ["workItems"], queryFn });
  return <WorkItemList items={data} />;
}

<Suspense fallback={<WorkItemListSkeleton rows={6} />}>
  <WorkItems />
</Suspense>;
```

## Skeletons

- Build from MUI `<Skeleton />` (`variant="text" | "rectangular" | "circular"`), sized to the real content.
- Match the real layout's structure and count — a list skeleton renders the same number of rows the list usually shows.
- Keep the skeleton next to the component it stands in for, so the two stay in sync when the layout changes.

## Errors

The goal is to keep the page rendering. A failed request must cost the user the smallest possible piece of the screen.

- Pair each Suspense boundary with an error boundary — suspense handles the pending state, the error boundary handles the thrown error (REST: `react-query` skill's error-propagation rule; GraphQL/urql: `api-calls` skill). Don't catch and return a default from the query function.
- **The boundary's position is the blast radius.** A throw travels to the nearest boundary above it, so a section with none of its own lands on the app root boundary and blanks the screen.
- **A boundary replaces the component that threw; it can never resume it.** A boundary around a page whose own hook throws still hides that page, so the read belongs in the piece that needs it.
- **Ambient data must not suspend.** Data read across the app and required to be correct by none of it — preferences, flags, locale — takes the page down when it throws. Read it with `useQuery`, fall back to the schema defaults, and alert.
- **A fallback must not depend on the data that failed**, or it throws again and escapes to the parent boundary.

## What to flag in review

- `if (isLoading) return <Spinner />` (or `<CircularProgress />`) for initial data load — should suspend with a skeleton fallback.
- `useQuery` where the component immediately branches on loading state — should be `useSuspenseQuery`.
- A single Suspense boundary at the app/page root making the whole screen blank while one section loads — each independently-fetching section needs its own boundary and skeleton.
- Fallbacks that are bare spinners or `null` where a layout-matching skeleton belongs.
- A Suspense boundary with no accompanying error boundary.
- `useSuspenseQuery` for preferences, flags or any other ambient data read across the app.
- A page whose top-level hook suspends or throws, so one failed request costs the entire page.
- An error-boundary fallback that renders the same data the boundary just failed on.

