---
name: code-no-defensive-fallbacks
description: Do not paper over missing values with `?? ''`, `|| 'Unknown'` or ternary defaults — one owner decides the fallback, everyone else passes the value through. Use when writing or reviewing code that handles optional values.
triggers:
  - model
  - user
---

# No Defensive Fallbacks

A fallback at every call site turns absent data into plausible-looking output. The bug stops being visible: nobody sees a crash or a blank, they see `''`, `Unknown`, `N/A` or `0`, and the real question — why is this value missing? — never gets asked. It also multiplies: once a helper has a default and the caller adds another, two places decide the answer and neither is authoritative.

## Rule

- **Defaulting to `''` is almost never right.** An empty string renders as nothing: a blank cell, a nameless avatar, a heading that isn't there. Nobody can tell whether the field was empty, the request failed, or the mapping is wrong. Prefer letting the value stay `undefined` and deciding what the user sees at the point of render.
- **One owner per fallback.** If a helper or component already handles the empty case, callers pass the raw value through. Never wrap a call that has an internal default in a second default.
- **Never add `?? ''` (or `|| ''`, `?? 0`, `?? []`) to satisfy a type.** If a caller legitimately holds `string | null | undefined`, widen the parameter — do not fabricate a value to get past the type checker.
- **Absent data that shouldn't be absent is a bug** — `assert` it (see `code-error-handling` and `code-trust-the-types`), don't default it.
- **Fallbacks belong at the render boundary**, where a human sees them, and must be translated (`translate(...)`), never a bare literal in business logic.
- **Never invent a fallback the caller did not ask for.** Preserve the branch that is already in the file.

## Examples

```typescript
// BAD — helper already returns '?' for an empty name, so this decides it twice
{
  requesterName ? getInitials(requesterName) : "?";
}
{
  getInitials(user?.name ?? "");
}

// GOOD — the helper owns the empty case; the caller passes the value
{
  getInitials(requesterName);
}
```

```typescript
// BAD — `?? ''` invented purely to satisfy a `string` parameter
function getInitials(name: string): string;
getInitials(execution.requesterName ?? "");

// GOOD — the signature admits what callers actually hold
function getInitials(name: string | null | undefined): string;
getInitials(execution.requesterName);
```

```typescript
// BAD — hides a broken response behind a friendly string
const owner = definition.ownerName ?? "Unknown";

// GOOD — render-boundary fallback, translated, decided once
const owner = definition.ownerName;
// ...
{
  owner ?? translate("flowDetails.ownerNotSet");
}
```

```typescript
// BAD — a failed lookup and a genuinely empty description look identical, and
// the empty string renders as a silently missing paragraph
description: resolveLocalizableText(definition.description, locale) ?? '',

// GOOD — absence stays absent, and the UI decides what to show
description: resolveLocalizableText(definition.description, locale),
```

## The one legitimate case

Feeding a value into something that throws on `null`/`undefined` — `.trim()`, `.toLowerCase()`, `new Date(...)`, a third-party API you don't control. There, `?? ''` is guarding a real crash, not hiding data.

Even then, if **we own the function**, fix it there instead: one null check inside beats a coalesce at every call site.

```typescript
// ACCEPTABLE — third-party API that throws on undefined
externalSdk.search(query ?? '');

// BETTER — our own helper, so it takes what callers actually hold
function searchFlows(query: string | undefined): Flow[] {
  if (!query) {
    return [];
  }
  ...
}
```

## Checklist

- [ ] Am I defaulting to `''`? Almost always wrong — keep it `undefined`.
- [ ] Does the callee already handle the empty case? Then no caller-side default.
- [ ] Is this `??`/`||` here only to make types compile? Fix the signature instead.
- [ ] Should this value always exist? `assert` it.
- [ ] Is the fallback user-visible? It must be translated and live at the render boundary.
- [ ] Did the existing code already handle this case? Leave it alone.

