---
name: code-error-handling
description: Error handling discipline — never swallow errors, always include context, let errors propagate when you can't add value, never leave promises unhandled. Use when writing or reviewing any code that uses try/catch, throws, or async.
---

# Error handling — never swallow, always context

Errors are signals. If something fails, the developer needs to know what was being attempted, where, and why. Silent failures hide bugs and waste debugging time.

## Never use empty catch blocks

```ts
// BAD — error disappears, nobody knows what happened
try {
  await fetchMatchData(matchId);
} catch (error) {}

// BAD — swallows error and returns misleading default
try {
  const data = await fetchMatchData(matchId);
  return data;
} catch (_error) {
  return null;
}

// GOOD — log context and rethrow
try {
  await fetchMatchData(matchId);
} catch (error) {
  console.error('fetchMatchData failed', { matchId }, error);
  throw error;
}
```

## Prefer letting errors propagate

Only catch when you can add value — retry, structured error, or meaningful recovery. If you're just going to rethrow unchanged, don't catch at all.

```ts
// BAD — catch adds nothing
try {
  return await getLeagueTable(leagueId);
} catch (error) {
  throw error;
}

// GOOD — just let it propagate
return await getLeagueTable(leagueId);

// GOOD — catch adds context that callers don't have
try {
  return await getLeagueTable(leagueId);
} catch (error) {
  throw new Error(`failed loading table for league ${leagueId}`, { cause: error });
}
```

## Always include context in error messages

A bare `console.error(error)` is nearly useless. Include what was being attempted and the relevant identifiers.

```ts
// BAD — no context
console.error(error);
console.error('something went wrong');

// GOOD — what, where, and the original error
console.error('failed to fetch fixtures', { leagueId, season }, error);
console.error('parseMatchStats: invalid response shape', { matchId }, error);
```

## Async — never leave promises unhandled

```ts
// BAD — fire and forget
fetchMatchData(matchId);
void fetchMatchData(matchId);

// BAD — .catch that swallows
fetchMatchData(matchId).catch(() => {});

// GOOD — handle or await
await fetchMatchData(matchId);

// GOOD — explicit catch with logging if fire-and-forget is intentional
fetchMatchData(matchId).catch((error) => {
  console.error('background fetch failed', { matchId }, error);
});
```

## Don't catch to recover — let it crash

If an operation fails, it failed. Don't catch and return a fallback that hides the failure. The caller needs to know something went wrong.

```ts
// BAD — silently substitutes a fallback, caller thinks everything worked
try {
  return await fetchMatchData(matchId);
} catch {
  return defaultMatchData;
}

// GOOD — let the error propagate, handle it at the top level
return await fetchMatchData(matchId);
```

## What to flag in review

- Empty `catch {}` or `catch (_) {}` blocks
- `catch` blocks that just rethrow unchanged
- `console.error(error)` with no context
- `.then(...).catch(() => {})` that swallows
- Fire-and-forget promises without `.catch` or `await`
- `try/catch` returning a fallback value that hides the failure

## Subprocesses — a null exit code is not success

`spawnSync`/`execSync` failures are not exceptions. A missing binary sets
`result.error` and leaves `result.status` as `null` — defaulting that to 0
turns a process that never ran into a "successful" one.

```ts
// BAD — tsx missing → status null → exits 0 → empty build published
const result = spawnSync(tsxBin, args, { stdio: 'inherit' });
process.exit(result.status ?? 0);

// GOOD — fail hard on spawn error, propagate real status
const result = spawnSync(tsxBin, args, { stdio: 'inherit' });
assert(!result.error, `failed to spawn ${tsxBin}: ${result.error?.message}`);
assert(result.status === 0, `${tsxBin} exited with ${result.status}`);
```

## What to flag in review (subprocesses)

- `result.status ?? 0` or any default-to-success on a null exit code
- `spawnSync`/`exec` results used without checking `result.error`
- Child process failures logged but the parent still exits 0
