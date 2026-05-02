---
name: code-trust-the-types
description: TypeScript discipline — trust the types, no defensive runtime checks for things the compiler already guarantees. No unnecessary `?.` / `??`, no fallback values that hide bugs, no widening types to add optionality. Use when writing or reviewing TypeScript.
---

# Trust the types — no defensive programming

If the type says a value exists, trust it. Don't add runtime guards for things TypeScript already guarantees.

## No unnecessary optional chaining

```ts
// BAD — match is Match, not Match | undefined
const team = match?.team_h ?? '';
const goals = match?.h_goals ?? 0;
const shots = data?.results?.map(r => r?.score) ?? [];

// GOOD — match is Match, access it directly
const team = match.team_h;
const goals = match.h_goals;
const shots = data.results.map(r => r.score);
```

## No fallback values that hide bugs

```ts
// BAD — if xg is missing, that's a data bug, don't hide it with 0
const xg = parseFloat(match.h_xg ?? '0');
const items = response.data ?? [];

// GOOD — if it's required, let it fail loudly
const xg = parseFloat(match.h_xg);
const items = response.data;
```

## No redundant null checks

```ts
// BAD — teams is Team[], it's always an array
if (teams && teams.length > 0) { ... }
if (typeof matchId !== 'undefined') { ... }

// GOOD
if (teams.length > 0) { ... }
```

## No widening types to add optionality

```ts
// BAD — adding | null when the field is always present
interface Match {
  home_team: string | null;
  h_xg: number | undefined;
}

// GOOD — if the API always returns it, the type should reflect that
interface Match {
  home_team: string;
  h_xg: number;
}
```

## Assert at boundaries, don't default

When receiving data from external sources, validate before proceeding. Never silently default.

```ts
// BAD — silently masks missing data
const team = response.team_h ?? 'Unknown';

// GOOD — fails immediately with a clear message
assert(!!response.team_h, 'match response missing home team');
const team = response.team_h;
```

(For comprehensive boundary validation, see `frontend-zod-validation`.)

## Only use `?.` and `??` when the type is actually optional

`?.` is for `T | undefined | null`. If the type is `T`, use `.` and let TypeScript catch the mistake at compile time.

## Never use `as unknown as` — fix the types

`as unknown as T` means the types are wrong. Don't force mismatched types through a double cast — fix the type definitions.

```ts
// BAD — types don't match, force it through unknown
const data = rawData as unknown as MyType;

// GOOD — define a proper type that matches the actual shape
interface GroupRow {
  id: string;
  group: string;
}
type TableRow = DataRow | GroupRow;
records.push({ id, group });
```

## No reflexive `as T` assertions — let the compiler infer

LLMs (and humans under time pressure) reach for `as T` to silence a red squiggle. **A type assertion is a promise to the compiler that you know better than it does.** Almost every time, you don't.

```ts
// BAD — assertion bypasses the check, doesn't fix the underlying mismatch
const user = response.data as User;
const ids = items.map((item) => item.id) as string[];
const config = JSON.parse(raw) as Config;
const handler = ((event) => { ... }) as ChangeEventHandler<HTMLInputElement>;
const value = formData.get('email') as string;

// GOOD — validate at the boundary (Zod), then trust the inferred type
const user = UserSchema.parse(response.data);
const config = ConfigSchema.parse(JSON.parse(raw));

// GOOD — let inference work
const ids = items.map((item) => item.id);

// GOOD — annotate the parameter, not the function
const handler = (event: ChangeEvent<HTMLInputElement>) => { ... };

// GOOD — narrow with a runtime check (FormDataEntryValue is string | File)
const email = formData.get('email');
assert(typeof email === 'string', 'email must be a string');
```

### When `as` is actually OK

Three legitimate uses, and that's it:

1. **`as const`** — narrows literal types: `['a', 'b'] as const`.
2. **Discriminated union narrowing where TypeScript can't follow** — usually a sign of a refactor opportunity, but sometimes unavoidable.
3. **`satisfies T`** instead of `as T` — checks the value matches T without widening it. Prefer this over `as` when you're checking a literal:
   ```ts
   // BAD
   const config = { host: 'localhost', port: 5432 } as DbConfig;
   // GOOD
   const config = { host: 'localhost', port: 5432 } satisfies DbConfig;
   ```

### Red flags that an `as` is hiding a real problem

- The line right before the `as` has a TS error without it.
- The asserted type is a *narrower* shape than the real value (you're claiming fewer optional fields than exist).
- The asserted type is a *wider* shape than the real value (you're claiming the value has fields it doesn't).
- The assertion is on the result of `JSON.parse`, `fetch().json()`, `localStorage.getItem`, or any `unknown`/`any` source — that's a boundary; use a schema.
- The assertion is on a function expression — annotate the parameters and return type instead.

## What to flag in review

- `?.` or `??` on a value whose type is non-optional
- `?? defaultValue` where the default would mask a data bug
- `if (x && x.length > 0)` where `x` is non-nullable
- Interface fields typed `T | null` / `T | undefined` when the source always provides them
- `as unknown as T` (and any other double-cast)
- `!` non-null assertion (forbidden — fix the types instead)
- **Any `as T` that isn't `as const` or `satisfies T`** — investigate. Most can be replaced by inference, parameter annotation, or schema validation.
- `as T` on `JSON.parse` / `fetch().json()` / `localStorage` / form data — boundary data, must be validated not asserted.
