---
description: Scaffold a pnpm monorepo (Volta, ESLint, leaf UI package, code-splitting frontend, api package, vitest per package), verified by a self-paced loop.
argument-hint: [path] [name]
allowed-tools: Bash, Read, Write, Edit, Glob
---

# New Monorepo

Scaffold a pnpm-workspace monorepo at `$1`, modelled on `../cuttingedge` and `../harbour-ui`. Code stays minimal — just enough to prove build, lint, typecheck, and test work.

Arguments: `$1` — target directory (default `.`). `$2` — repo name (default: basename of target).

**Package boundary rule**: leaf UI packages build in Vite library mode, externalising every dependency — unbundled `preserveModules` ESM, never a bundle. Only `apps/frontend` bundles and vendor-splits; `packages/api` just compiles with `tsc`.

## Steps

### 1. Resolve target and guard against clobbering

```bash
TARGET="${1:-.}"
mkdir -p "$TARGET"
cd "$TARGET"
REPO_NAME="${2:-$(basename "$(pwd)")}"
ls -la
```

If the directory already contains a `package.json`, `pnpm-workspace.yaml`, `apps/`, or `packages/`, stop and ask the user how to proceed rather than overwriting.

### 2. Root workspace files

Write `pnpm-workspace.yaml`:

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

Write root `package.json`:

```json
{
  "name": "<REPO_NAME>",
  "version": "0.1.0",
  "private": true,
  "packageManager": "pnpm@11.13.1",
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "lint": "eslint .",
    "test": "turbo run test",
    "typecheck": "turbo run typecheck"
  },
  "devDependencies": {
    "@eslint/js": "^10.0.1",
    "eslint": "^10.7.0",
    "eslint-plugin-react": "^7.37.5",
    "eslint-plugin-react-hooks": "^7.1.1",
    "globals": "^17.7.0",
    "turbo": "^2.9.18",
    "typescript": "^5.6.0",
    "typescript-eslint": "^8.64.0"
  },
  "volta": {
    "node": "24.18.0",
    "pnpm": "11.13.1"
  }
}
```

Write `turbo.json`:

```json
{
  "$schema": "https://turborepo.org/schema.json",
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "dev": { "cache": false, "persistent": true },
    "lint": { "outputs": [] },
    "test": { "dependsOn": ["^build"], "outputs": [] },
    "typecheck": { "outputs": [] }
  }
}
```

Write shared `tsconfig-base.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true
  }
}
```

Write root `eslint.config.mjs` (self-contained flat config):

```js
import js from '@eslint/js';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['**/dist/**', '**/.turbo/**', '**/node_modules/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
    plugins: { react, 'react-hooks': reactHooks },
    rules: {
      ...react.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      'react/react-in-jsx-scope': 'off',
    },
    settings: { react: { version: 'detect' } },
  },
);
```

Write `.gitignore`:

```
node_modules/
dist/
.turbo/
*.tsbuildinfo
.env
```

### 3. `packages/ui` — leaf package, everything externalised

`packages/ui/package.json`:

```json
{
  "name": "ui",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "sideEffects": false,
  "module": "dist/esm/index.js",
  "types": "dist/esm/index.d.ts",
  "exports": {
    "types": "./dist/esm/index.d.ts",
    "import": "./dist/esm/index.js"
  },
  "scripts": {
    "dev": "vite build --watch",
    "build": "vite build",
    "typecheck": "tsc -b --noEmit",
    "lint": "eslint ./src",
    "test": "vitest run"
  },
  "peerDependencies": {
    "react": "^19.2.0"
  },
  "devDependencies": {
    "@testing-library/react": "^16.1.0",
    "@types/react": "^19.2.0",
    "@vitejs/plugin-react": "^6.0.3",
    "jsdom": "^29.1.1",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "typescript": "^5.6.0",
    "vite": "^8.1.5",
    "vite-plugin-dts": "^5.0.3",
    "vitest": "^4.1.9"
  }
}
```

`packages/ui/tsconfig.json`:

```json
{
  "extends": "../../tsconfig-base.json",
  "compilerOptions": {
    "jsx": "react-jsx",
    "rootDir": "src",
    "noEmit": true
  },
  "include": ["src"]
}
```

`packages/ui/vite.config.mts`:

```ts
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';
import dts from 'vite-plugin-dts';

export default defineConfig({
  plugins: [react(), dts({ tsconfigPath: 'tsconfig.json', insertTypesEntry: true, logLevel: 'error' })],
  build: {
    outDir: 'dist/esm',
    sourcemap: true,
    lib: {
      entry: 'src/index.ts',
      formats: ['es'],
    },
    rolldownOptions: {
      external: [/^react/, /^react-dom/],
      output: {
        preserveModules: true,
        preserveModulesRoot: 'src',
        format: 'esm',
      },
    },
  },
  test: {
    environment: 'jsdom',
    exclude: ['dist/**', 'node_modules/**'],
  },
});
```

`packages/ui/src/Button.tsx`:

```tsx
type ButtonProps = {
  readonly label: string;
  readonly onClick?: () => void;
};

export function Button({ label, onClick }: ButtonProps) {
  return <button onClick={onClick}>{label}</button>;
}
```

`packages/ui/src/index.ts`:

```ts
export { Button } from './Button';
```

`packages/ui/src/Button.test.tsx`:

```tsx
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { Button } from './Button';

describe('Button', () => {
  it('renders the label and calls onClick when clicked', () => {
    const onClick = vi.fn();
    render(<Button label="it works" onClick={onClick} />);

    const button = screen.getByText('it works');
    fireEvent.click(button);

    expect(onClick).toHaveBeenCalledTimes(1);
  });
});
```

### 4. `apps/frontend` — the app that actually bundles

`apps/frontend/package.json`:

```json
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "typecheck": "tsc -b --noEmit",
    "lint": "eslint ./src",
    "test": "vitest run"
  },
  "dependencies": {
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "ui": "workspace:*"
  },
  "devDependencies": {
    "@testing-library/react": "^16.1.0",
    "@types/react": "^19.2.0",
    "@types/react-dom": "^19.2.0",
    "@vitejs/plugin-react": "^6.0.3",
    "jsdom": "^29.1.1",
    "typescript": "^5.6.0",
    "vite": "^8.1.5",
    "vitest": "^4.1.9"
  }
}
```

`apps/frontend/tsconfig.json`:

```json
{
  "extends": "../../tsconfig-base.json",
  "compilerOptions": {
    "jsx": "react-jsx",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "noEmit": true,
    "rootDir": "src"
  },
  "include": ["src"]
}
```

`apps/frontend/vite.config.mts`:

```ts
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

const isProd = process.env.NODE_ENV !== 'development';

export default defineConfig({
  plugins: [react()],
  server: { port: 3000 },
  build: {
    sourcemap: !isProd,
    minify: isProd,
    rolldownOptions: {
      output: {
        format: 'esm',
        codeSplitting: {
          groups: [
            {
              name: 'vendor-react',
              test: /node_modules[\\/](react|react-dom)/,
              priority: 10,
            },
          ],
        },
      },
    },
  },
  test: {
    environment: 'jsdom',
    exclude: ['dist/**', 'node_modules/**'],
  },
});
```

`apps/frontend/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>frontend</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

`apps/frontend/src/main.tsx`:

```tsx
import { createRoot } from 'react-dom/client';

import { App } from './App';

createRoot(document.getElementById('root')!).render(<App />);
```

`apps/frontend/src/Panel.tsx` — loaded lazily, its own chunk:

```tsx
import { Button } from 'ui';

export default function Panel() {
  return <Button label="it works" onClick={() => console.log('clicked')} />;
}
```

`apps/frontend/src/App.tsx` — lazy-loads `Panel` via `React.lazy` + `Suspense`:

```tsx
import { lazy, Suspense } from 'react';

const Panel = lazy(() => import('./Panel'));

export function App() {
  return (
    <>
      <h1>frontend is running</h1>
      <Suspense fallback={<p>Loading…</p>}>
        <Panel />
      </Suspense>
    </>
  );
}
```

`apps/frontend/src/App.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { App } from './App';

describe('App', () => {
  it('renders and loads the lazy Panel', async () => {
    render(<App />);

    expect(screen.getByText('frontend is running')).toBeTruthy();
    expect(await screen.findByText('it works')).toBeTruthy();
  });
});
```

### 5. `packages/api` — minimal Node + TS API

`packages/api/package.json`:

```json
{
  "name": "api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -b",
    "start": "node dist/index.js",
    "typecheck": "tsc -b --noEmit",
    "lint": "eslint ./src",
    "test": "vitest run"
  },
  "dependencies": {
    "express": "^5.2.1"
  },
  "devDependencies": {
    "@types/express": "^5.0.6",
    "@types/node": "^22.0.0",
    "@types/supertest": "^6.0.2",
    "supertest": "^7.0.0",
    "tsx": "^4.22.4",
    "typescript": "^5.6.0",
    "vitest": "^4.1.9"
  }
}
```

`packages/api/tsconfig.json`:

```json
{
  "extends": "../../tsconfig-base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
    "types": ["node"]
  },
  "include": ["src"]
}
```

`packages/api/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    exclude: ['dist/**', 'node_modules/**'],
  },
});
```

`packages/api/src/app.ts` — Express app on its own so `supertest` can hit it directly:

```ts
import express from 'express';

export const app = express();

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});
```

`packages/api/src/index.ts`:

```ts
import { app } from './app';

const port = process.env.PORT ?? 4000;

app.listen(port, () => {
  console.log(`api listening on port ${port}`);
});
```

`packages/api/src/app.test.ts`:

```ts
import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { app } from './app';

describe('GET /health', () => {
  it('returns ok', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });
});
```

### 6. Install, then loop until clean

```bash
pnpm install
```

Invoke the `loop` skill with **no interval** (self-paced) so it resumes via `ScheduleWakeup` across turns. Prompt:

> Run in order: `pnpm --filter ui build`, `pnpm --filter frontend build`, `pnpm --filter api build`, `pnpm lint`, `pnpm typecheck`, `pnpm test`. On failure, fix the underlying code (never weaken/delete the check) and re-run from the top — a fix in one package can break another. Verify `apps/frontend/dist` has a `vendor-react` chunk and a `Panel` chunk, and `packages/ui/dist/esm` keeps `react` as a bare import (grep `from "react"`, not inlined). Call `ScheduleWakeup` with `stop: true` once everything is clean on a full run.

Report `ls -la apps/frontend packages/ui packages/api` once the loop stops.