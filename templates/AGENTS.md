# <project name>

<One sentence: what this project is and does.>

## Layout

```
<top-level dirs and what lives in each — keep to the dirs an agent actually needs>
```

## Stack

<Language(s), framework(s), package manager, infra. One line each.>

## Commands that work

```bash
# install
# build
# test (single file + full suite)
# lint / typecheck
# run locally
```

Only list commands verified in this repo. If a command needs env vars, say which.

## Conventions

- <naming, file placement, error handling, testing style — only rules that differ from ecosystem defaults>
- API endpoints are constants in a shared `urls` module — never inline the same URL string twice. See the `frontend-api-calls` skill.
- Import from a package's barrel, not per-component subpaths; side-effect modules get their own subpath. See the `frontend-bundle-imports` skill.
- Components sit at the correct atomic level (atoms/molecules/templates/pages) with companion files colocated, no barrel `index.ts`, 200-line cap. See the `frontend-component-structure` skill.
- No boolean flags for options that select a mode or variant — use a named string-literal union. See the `frontend-no-boolean-params` skill.
- No defensive fallbacks (`?? ''`, `|| 'Unknown'`) — one owner decides the fallback and it lives at the render boundary. See the `code-no-defensive-fallbacks` skill.
- Anything returning JSX is a component, not a `renderX()` helper; `styled()` and `keyframes` live in `styles.ts`. See the `frontend-no-render-functions` skill.
- Shared skills in `.claude/skills/` cover general conventions; list only project-specific rules here.

## Do not

- <things the agent must never do in this repo: files not to touch, patterns that are banned, commands that are destructive>

## Verification

<How the agent proves a change works before claiming done: which test command, which build, what output counts as passing.>

---

_Keep this file under 300 lines. Prune it when you touch it — every paragraph is standing context on every turn, in every session. CLAUDE.md is a symlink to this file so Claude Code and AGENTS.md-reading tools (Devin, Codex, Cursor) share one source of truth._
