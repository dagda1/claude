---
name: no-unnecessary-effects
description: useEffect is for synchronising with something outside React — never for click handling, derived values, or state the effect itself sets, in Harbour frontend
triggers:
  - model
  - user
---

# No Unnecessary Effects

`useEffect` runs after React draws. Anything you put there happens one render late, so the user sees the intermediate frame, and the effect re-runs whenever any dependency changes, not when the thing you had in mind happens. Reach for it only to synchronise with something outside React: a subscription, a timer, an imperative DOM API. Three rules cover almost every misuse in this repo.

## Rule

- **A click is an event, not a render.** Anything caused by a user action goes in the handler that the action fires. That includes closing a drawer or modal, resetting a form, posting a mutation, sending analytics, and telling a parent what changed.
- **A value the render can compute needs no state and no effect.** Derive it in the component body, or in `useMemo` when it is genuinely expensive. Never hold a second piece of state that an effect keeps in step with the first.
- **Never list the state an effect sets in its own dependencies.** The effect then runs on its own writes, so it undoes or repeats whatever else set that state. If you need the current value in order to decide, read it in the updater instead.

## Examples

```tsx
// BAD — the effect fires on every mode change, so the tap that opens the
// drawer is immediately undone by the effect that meant to watch navigation
useEffect(() => {
  if (sidebarMode === "drawer") {
    setSidebarMode("collapsed");
  }
}, [location.pathname, sidebarMode, setSidebarMode]);
```

```tsx
// GOOD — the click closes the drawer, in the handler that the click fires
<ButtonBase
  component={NavLink}
  to={item.to}
  onClick={() => {
    if (sidebarMode === "drawer") {
      setSidebarMode("collapsed");
    }
  }}
/>
```

```tsx
// BAD — state mirroring state, one render behind and wrong on the first paint
const [visibleFlows, setVisibleFlows] = useState<Flow[]>([]);

useEffect(() => {
  setVisibleFlows(flows.filter((flow) => flow.status === status));
}, [flows, status]);
```

```tsx
// GOOD — computed while rendering, correct on every frame
const visibleFlows = flows.filter((flow) => flow.status === status);
```

```tsx
// BAD — resetting on a prop change, which React does for you
useEffect(() => {
  setDraft("");
}, [flowId]);

// GOOD — a new key gives a new component with fresh state
<FlowEditor key={flowId} />;
```

```tsx
// BAD — the effect depends on the state it writes
useEffect(() => {
  if (open && step === "review") {
    setStep("summary");
  }
}, [open, step]);

// GOOD — decide inside the updater, so only the real trigger is a dependency
useEffect(() => {
  setStep((current) => (current === "review" ? "summary" : current));
}, [open]);
```

## Checklist

- [ ] Did a user action cause this? Move it into the handler.
- [ ] Can the render compute this value? Delete the state and the effect.
- [ ] Does the dependency list hold the state this effect sets? Read it in the updater.
- [ ] Is the effect resetting state because a prop changed? Use `key`.
- [ ] What outside React does this effect synchronise with? If the answer is nothing, it should not exist.

