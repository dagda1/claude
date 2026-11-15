---
name: astro-conventions
description: Astro site conventions — what goes in .astro pages and .tsx components, typing, structure, tests and data. Use when writing or reviewing an Astro site.
---

# Astro conventions

The React skills, cut down to what a static Astro site needs.

## .astro or .tsx

- `.astro`: pages and layouts. They load data, compose components and hold the page text.
- `.tsx`: every reusable component. Rendered at build time; no `client:*` directive
  unless the component needs to run in the browser.
- No logic in `.astro` frontmatter beyond imports, loading data and passing props.

## Components (.tsx)

- Named function declaration, explicit `JSX.Element` return type. No arrow components,
  no `React.FC`, no `React.*` type namespace.
- Props in a named `interface`, wrapped in `Readonly<Props>`. Never inline.
- Returns JSX → it is a component, in its own file. No `renderX()` helpers.
- A prop that selects a mode or variant is a string-literal union, not a boolean.
- One component per file. Max 200 lines; split by extracting a component.

## .astro files

- Props typed with `interface Props`, read from `Astro.props`.
- Max 200 lines. Markup that repeats becomes a `.tsx` component.

## Structure

- Each component in its own PascalCase folder, with its test beside it:
  `components/PpdaChart/{PpdaChart.tsx, PpdaChart.test.tsx}`.
- No barrel `index.ts`. Import from the source file.
- No `../` imports. Use the path alias (`~/`).
- Search for an existing component before writing one. Never copy-paste a component.

## Tests

- Render the component and assert on what the reader sees: text, roles, SVG elements.
  Never assert on props or internals.
- Real data shapes as fixtures: a slice of the real JSON, not a made-up partial.
- No "renders without crashing" tests.

## Data

- All site data is local JSON, read at build time. No API calls from pages or components.
- Every data file is a content collection in `src/content.config.ts`: a `file()` or
  `glob()` loader from `astro/loaders` and a Zod schema from `astro/zod`.
- Pages read data with `getCollection()` / `getEntry()` from `astro:content`. Never
  `import` a JSON file or read it with `fs`.
- The type is inferred from the collection schema. No `as` casts, no checks further in.
- Components take data as props. Only `.astro` pages touch collections.

## What to flag in review

- A `client:*` directive with no browser behaviour that needs it.
- Logic or repeated markup in a `.astro` file that belongs in a component.
- Arrow components, `React.FC`, inline prop types, missing return types.
- A function returning JSX that is not a component.
- A boolean prop that selects a variant.
- `index.ts` re-exports, `../` imports, a component without a colocated test.
- Data read outside a content collection: a JSON `import`, `fs`, or a `fetch`.
- A component that reads a collection instead of taking props.
