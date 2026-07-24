---
name: api-calls
description: How to call APIs in Harbour frontend — react-query for REST, urql for GraphQL, all responses parsed by a Zod schema
triggers:
  - model
  - user
---

# Calling APIs

Two transports. Every response is parsed by a Zod schema before use.

| Kind    | Tool                             | Use for                                                      |
| ------- | -------------------------------- | ------------------------------------------------------------ |
| REST    | `@tanstack/react-query` + `xior` | `useQuery` for GETs, `useMutation` for POST/PUT/PATCH/DELETE |
| GraphQL | `urql`                           | `useQuery` from `urql` with a typed `graphql()` document     |

Import `urls` and `xior` from `@harbour/core`. Never use `fetch`.

## REST — GET (`useQuery`)

```typescript
import { urls, xior } from "@harbour/core";
import { useQuery } from "@tanstack/react-query";
import { workItemSchema } from "~/pages/WorkItems/types";

export function useWorkItem(workItemId?: string) {
  return useQuery({
    queryKey: ["workItem", workItemId],
    queryFn: async () => {
      const response = await xior.get(`${urls.WorkItems}/${workItemId}`);
      return workItemSchema.parse(response.data);
    },
    enabled: !!workItemId,
  });
}
```

- Hierarchical query keys: `['workItem', id]`, `['workItems']`.
- Parse `response.data` with the Zod schema and return the parsed result.

## REST — mutations (`useMutation`)

```typescript
import { useLocale } from "@harbour/translator";
import { urls, useApplicationStore, xior } from "@harbour/core";
import { useMutation, useQueryClient } from "@tanstack/react-query";

export function useCreateWorkItem() {
  const queryClient = useQueryClient();
  const alertApi = useApplicationStore((state) => state.alertApi);
  const { translate } = useLocale();

  return useMutation({
    mutationFn: async (data: CreateWorkItemRequest) => {
      const response = await xior.post(urls.WorkItems, data);
      return createWorkItemSchema.parse(response.data);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["workItems"] });
    },
    onError: (error) => {
      alertApi.postError(
        error,
        translate("harbour.errors.workItems.createFailed"),
      );
    },
  });
}
```

- `xior.post` / `.patch` / `.delete`; `mutationFn` returns the parsed response.
- Invalidate related queries in `onSuccess` (include `activityLog` / `activityCount` where relevant — see `react-hooks` skill).
- Report failures via `alertApi.postError(error, translate(...))`; never swallow errors.
- Use `onMutate` for optimistic updates covering every mutable field, with rollback in `onError`.

## GraphQL — `urql`

```typescript
import { useQuery } from "urql";
import { graphql } from "~/gql";
import { copilotMetricsSchema } from "~/models/copilotMetricsSchema";
import { useParseSchema } from "~/queries/useParseSchema";

const fetchCopilotMetricsSummary = graphql(/* GraphQL */ `
  query fetchCopilotMetricsSummary($startDate: String, $endDate: String) {
    copilotMetricsSummary(
      filter: { startDate: $startDate, endDate: $endDate }
    ) {
      startDate
      endDate
      totalActiveUsers
    }
  }
`);

const suspenseContext = { suspense: true };

export function useFetchCopilotMetricsSummary({ startDate, endDate }) {
  const [result] = useQuery({
    query: fetchCopilotMetricsSummary,
    variables: { startDate, endDate },
    context: suspenseContext,
  });
  const parseSchema = useParseSchema();
  return parseSchema(copilotMetricsSchema, result.data?.copilotMetricsSummary);
}
```

- Build documents with `graphql()` from `~/gql` (typed via codegen).
- Use `context: { suspense: true }` for suspense-based data fetching.

## Zod parsing — required for every response

- **Never return raw response data.** Parse it through a Zod schema first (see `zod-schemas` skill).
- **GraphQL (urql):** use `useParseSchema()` (`~/queries/useParseSchema`). It throws a localized error and reports Zod errors on invalid/empty data. This helper is GraphQL-only — don't reach for it in REST hooks.

  ```typescript
  const parseSchema = useParseSchema();
  return parseSchema(mySchema, result.data?.field);
  ```

- **REST (react-query):** parse `response.data` directly with `mySchema.parse(data)`, or `safeParse` when you need to handle the failure inline.
- **Zod error logging is generic** via `useReportZodError` from `@harbour/core` — parse failures are reported centrally, so don't build bespoke logging per hook.

## Where these live

- REST hooks: `apps/frontend/src/hooks/<feature>/`
- GraphQL queries: `apps/ithealth/src/queries/`

## Checklist

- [ ] GETs use `useQuery`; writes use `useMutation` (REST) or `urql` for GraphQL
- [ ] `urls` and `xior` imported from `@harbour/core`, no `fetch`
- [ ] Response parsed by a Zod schema (REST: `schema.parse`; GraphQL: `useParseSchema`)
- [ ] Query keys hierarchical; related queries invalidated on mutation success
- [ ] Errors surfaced via `alertApi.postError(error, translate(...))`
