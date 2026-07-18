# claude

Personal repo of reusable Claude Code skills and workflows. Symlinked into projects so each project picks up the same conventions without duplicating files.

## Layout

```
~/claude/
├── workflows/         ← symlinks into <project>/.claude/commands/
│   └── branch-review.md
├── agents/            ← symlinks into <project>/.claude/agents/
│   └── reviewer.md    ← fresh-context verifier used by /branch-review
├── templates/
│   └── AGENTS.md      ← copied (not symlinked) into new projects; CLAUDE.md links to it
├── .claude/
│   └── settings.json  ← shared permissions, symlinked into <project>/.claude/settings.json
└── skills/            ← symlinks into <project>/.claude/skills/
    ├── assistant-*/   ← always-on behavior (communication, modification policy, output)
    ├── code-*/        ← language-agnostic conventions (errors, types, style, tests)
    ├── frontend-*/    ← React/MUI/TS conventions
    └── review-*/      ← used by /branch-review
```

Each skill is a folder containing a `SKILL.md` with YAML frontmatter (`name`, `description`) and the rule body. Each workflow is a single markdown file with frontmatter that becomes a `/slash-command`.

## Symlink into a new project

From the project root:

```bash
mkdir -p .claude/commands
ln -s ~/claude/skills .claude/skills
ln -s ~/claude/workflows/branch-review.md .claude/commands/branch-review.md
```

Result:

```
<project>/.claude/
├── commands/branch-review.md → ~/claude/workflows/branch-review.md
└── skills → ~/claude/skills
```

Verify:

```bash
ls -la .claude/skills .claude/commands/branch-review.md
# both should show the lrwxr-xr-x permissions and `->` arrow
```

Edit the source in `~/claude/`, every project picks up the change.

## Add a new skill

```bash
mkdir -p ~/claude/skills/<category>-<name>
$EDITOR ~/claude/skills/<category>-<name>/SKILL.md
```

Use the existing skills as templates. Frontmatter shape:

```markdown
---
name: <category>-<name>
description: One sentence describing when to load this skill — Claude reads this to decide.
---

# Skill body
```

Naming convention is `<category>-<thing>`:

| Prefix | When it applies |
|--------|----------------|
| `assistant-` | Always-on behavior of the assistant itself |
| `code-` | Language-agnostic code conventions |
| `frontend-` | React/MUI/TypeScript conventions |
| `cdk-` | AWS CDK constructs, IAM, stateful resources, custom resources |
| `review-` | Process for `/branch-review` |

Add new prefixes as new domains appear (`backend-`, `terraform-`, etc.).

## Subagents

Agents live in `agents/` as markdown with YAML frontmatter (`name`, `description`, `tools`), symlinked to `<project>/.claude/agents/` by `install.sh`. The `reviewer` agent runs `/branch-review` steps 1–9 in a fresh context via the Task tool, so the verdict never comes from the same context that wrote the code. The main context keeps the fix loop (step 10).

## AGENTS.md / CLAUDE.md

Each project gets one canonical context file, `AGENTS.md` (read natively by Devin, Codex, Cursor), with `CLAUDE.md` as a symlink to it for Claude Code. `install.sh` copies `templates/AGENTS.md` into the project if absent and creates the link. Per-project content — edit it in the project, keep it under 300 lines, prune on touch.

## Permissions

`.claude/settings.json` here is the shared permission set, symlinked into every project by `install.sh`: read-only commands (ls, cat, grep, rg, find, git status/diff/log/show/branch/fetch) run without prompting, `rm` always asks, `aws` is denied outright. Precedence is deny > ask > allow. Machine- or project-specific additions go in the project's `.claude/settings.local.json`, which is unversioned. If a project already has a real (non-symlink) settings.json, install.sh leaves it and tells you to merge.

## Add a new workflow

```bash
$EDITOR ~/claude/workflows/<name>.md
```

Then in each project that should have it:

```bash
ln -s ~/claude/workflows/<name>.md .claude/commands/<name>.md
```

Frontmatter shape:

```markdown
---
description: One-line description shown in `/` command list.
argument-hint: [arg1] [arg2]
allowed-tools: Bash, Read, Grep, Glob
---
```

## Reference from a workflow

Workflows can tell Claude to load specific skills before doing work. Example from `branch-review.md`:

```markdown
Always load (read in parallel):
- `.claude/skills/review-pr-size/SKILL.md`
- `.claude/skills/review-commit-hygiene/SKILL.md`

Conditionally load based on what changed:
- Frontend files → `.claude/skills/frontend-react-typescript/SKILL.md` etc.
```

This keeps the workflow body tight and the skills independently reusable.

## Caveats

- Symlinks aren't reliably watched for live changes by Claude Code. Restart the session after editing a skill or workflow to be safe.
- Skills auto-load when their `description` matches what Claude is doing. To force-load one, reference it explicitly from a workflow or in the user prompt (e.g. "apply the `code-trust-the-types` skill").
