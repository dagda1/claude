---
name: frontend-zod-validation
description: Validate untrusted data with Zod at system boundaries (API responses, scraped HTML, parsed JSON, env vars). Use when reviewing or writing code that ingests external data.
---

# Zod validation at boundaries

External data is the main source of runtime surprises. Validate at the boundary; trust the types after that.

## Define schema, infer type

One source of truth — the schema. Derive the type from it.

```ts
import { z } from 'zod';

const UserSchema = z.object({
  id: z.string(),
  email: z.email(),
  createdAt: z.iso.datetime(),
});

type User = z.infer<typeof UserSchema>;
```

## Validate at the edge

```ts
// right — fail at the boundary with a clear error
const data = UserSchema.parse(response.data);
useUserSomewhere(data);

// wrong — defensive checks scattered through business logic
function useUserSomewhere(data: unknown) {
  if (typeof data === 'object' && data && 'email' in data) { ... }
}
```

## Where to apply

- HTTP responses (REST, GraphQL).
- WebSocket messages.
- Scraped HTML / parsed JSON / CSV.
- `process.env` (env vars are strings until parsed).
- LocalStorage / IndexedDB reads.
- IPC / cross-tab messages.

## What to flag in review

- API responses typed via `as User` or `as unknown as User` instead of parsed.
- `JSON.parse(...)` without subsequent validation.
- `process.env.X` used directly as a non-string type without parsing.
- Defensive `typeof` / `in` checks scattered through business logic that should have been one `parse` at the boundary.
- Schema and type defined separately (drift risk) — should infer one from the other.
