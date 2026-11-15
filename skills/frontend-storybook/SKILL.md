---
name: frontend-storybook
description: Storybook story conventions — no providers or router in a story, route decorators, msw for data, typed decorators. Use when writing or reviewing a *.stories.tsx file.
---

# Storybook Stories

Pages and shared component-library components need stories for all variants. Other
components need none, and a missing story on one is never raised in review. This skill
is about the stories; for unit tests see the `frontend-testing` and `no-tautological-tests`
skills.

## A story never wraps itself in providers or a router

A test provider wrapper (such as `TestProviders`) is a **test** helper. It mounts a
`MemoryRouter`, a `QueryClient` and every store of its own, and may initialise i18n at module
load. In a story that is wrong twice over: it expects a jsdom environment, and its router nests
inside the `BrowserRouter` that `.storybook/preview.tsx` already provides, so the story renders
against a second history the browser URL never updates. The `frontend-testing` skill tells you
to render with the app's providers — that applies to `*.test.tsx` only. Never import a test
helper package from a `*.stories.tsx`, apart from shared decorators.

Providers, theme, router, query client and stores come from `preview.tsx` once. A story adds
nothing but the route it needs.

## Put a story at a URL by navigating the router that is already there

```tsx
// .storybook/decorators.tsx
function PathHost({ initialPath, children }: Readonly<PathHostProps>): JSX.Element {
  const navigate = useNavigate();
  const [navigateOnMount] = useState(() => navigate);

  useEffect(() => {
    navigateOnMount(initialPath, { replace: true });
  }, [navigateOnMount, initialPath]);

  return <>{children}</>;
}
```

Never put `navigate` itself in the effect's dependencies. Under `BrowserRouter` it changes
identity on every navigation, so the effect re-fires and sends every link click in the story
straight back to `initialPath`.

- `withPath(initialPath)` — a component that reads the URL but is not routed.
- `withRoute(initialPath, routePath, nestedRoutes?)` — a page with route params; renders
  `<Routes>` so `useParams` resolves.

```tsx
// GOOD
const teamRoute = withRoute(
  `/teams/${MOCK_TEAM_ID}`,
  '/teams/:teamId',
  <Route index element={<TeamOverviewTab />} />,
);

const meta: Meta<typeof TeamDetail> = {
  decorators: [teamRoute],
  parameters: { msw: { handlers: teamHandlers } },
};
```

```tsx
// BAD — a second router and a test helper in a story
<TestProviders initialEntries={['/teams/1']}>
  <Routes>...</Routes>
</TestProviders>
```

Under a pathless parent route there is no `/` to match, because the browser URL is
`/iframe.html`. Use `path="*"` for a story that needs an outlet context but no params, and a
real param path when the component calls `useParams`.

## Data comes from msw, not from the query cache

Pre-filling the cache with `queryClient.setQueryData` skips the component's own fetch and Zod
parse, so the story proves nothing about either and drifts silently when the schema changes.
Serve the endpoint instead, from a fixture in `__mocks__/`:

```tsx
const productHandlers = [
  http.get('*/api/products/:productId', () => HttpResponse.json(sampleProductResponse)),
];
```

A handler that has to derive its answer from the request asserts rather than guessing:

```tsx
http.get(REPOSITORIES_URL, ({ request }) => {
  const productId = new URL(request.url).searchParams.get('productId');
  assert(!!productId, 'the repositories request must carry a productId');
  ...
});
```

Give every page a `Loading` story with `delay('infinite')`, and an error story where the failure
path is worth seeing.

## Type a decorator as `Decorator`

Name the decorator, type it `Decorator`, and let `Story` infer:

```tsx
import type { Decorator, Meta } from '@storybook/react-vite';

const withTeam: Decorator = function WithTeam(Story) {
  return (
    <WithTeam>
      <Story />
    </WithTeam>
  );
};

const meta: Meta<typeof Component> = {
  decorators: [withTeam],
};
```

Annotating the parameter instead is what breaks: `Story: StoryFn` raises
`TS2786: 'Story' cannot be used as a JSX component`, and `Story: FC` only silences it by lying
about the type. A parameterised decorator returns a `Decorator` from a factory.

## Where story helpers live

Decorators, msw handler lists and story-only routing hosts go in the app's `.storybook/` folder;
fixtures and mock payloads in `__mocks__/`, named `mock<Thing>.ts`. Never in `src`, and never
exported from a shipped barrel — see the `frontend-bundle-imports` skill.

Story helpers must never reach the main bundle. Shipped code is everything the app entry
imports, directly or through a barrel. It never imports:

- a `*.stories.tsx` file, or anything under `.storybook/` or `__mocks__/`;
- `msw`, `@storybook/*` or a test helper package.

The import goes one way only: a story imports the component, never the reverse. One such import
in shipped code pulls the helper, its fixtures and `msw` into what every user downloads. When a
component and its story need the same value, the value lives beside the component and the story
imports it from there.

Flag in review: a story helper, decorator, handler list or fixture in `src`; a barrel that
re-exports one; a non-story file that imports any of the above.

## Skeletons are exempt

A `*Skeleton.tsx` needs **no story of its own** — a grey box out of context shows nothing. Never
raise its absence in review. Show it through the `Loading` story of the component or page that
renders it, with the request held open by `delay('infinite')`.

## Template

```tsx
import type { Meta, StoryObj } from '@storybook/react-vite';

import { Component } from './Component';

const meta: Meta<typeof Component> = {
  title: 'Molecules/Component',
  component: Component,
  parameters: { layout: 'centered' },
  tags: ['autodocs'],
};

export default meta;

type Story = StoryObj<typeof meta>;

export const Default: Story = {};
export const WithError: Story = {};
```

## Commands

```bash
pnpm --filter <package> storybook
```
