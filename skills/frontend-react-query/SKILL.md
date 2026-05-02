---
name: frontend-react-query
description: TanStack React Query patterns — query keys, mutation invalidation, error handling. Use when reviewing or writing code that uses @tanstack/react-query.
---

# React Query patterns

## Hierarchical query keys

Treat keys like file paths — narrowest unit last. Invalidating `['workItems']` invalidates every key that starts with it.

```ts
['workItems']                         // list
['workItems', { status: 'open' }]    // filtered list
['workItem', workItemId]              // single item
['workItem', workItemId, 'comments'] // sub-resource
```

Extract a `queryKeys` factory if the same keys appear in multiple files.

## Mutations invalidate every related query

The #1 cause of "stale UI" bugs is forgetting to invalidate an aggregate / activity log / count.

```ts
useMutation({
  mutationFn: updateWorkItem,
  onSuccess: (_, { workItemId }) => {
    queryClient.invalidateQueries({ queryKey: ['workItem', workItemId] });
    queryClient.invalidateQueries({ queryKey: ['workItems'] });
    queryClient.invalidateQueries({ queryKey: ['activityLog', workItemId] });
    queryClient.invalidateQueries({ queryKey: ['activityCount', workItemId] });
  },
});
```

## Errors propagate

Don't catch query/mutation errors and return defaults. Let `isError` / error boundaries handle them.

## What to flag in review

- Hand-written query keys as bare strings, not arrays.
- Mutations that change server state but call no `invalidateQueries`.
- Mutations that invalidate the primary list but forget activity log / count / aggregate views.
- Query functions that catch and return `null` on error — should throw so React Query handles it.
- Missing explicit return types on hooks built around `useQuery` / `useMutation`.
