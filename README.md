# claude

Personal repo of reusable Claude Code skills. Symlinked into projects so each project picks up the same conventions without duplicating files.

## Harness: `/spec` → `/build`

The way to do a piece of work. You talk to the agent once, before the build, and review the changes after it. Checks — not you — correct the agent during the build. Nothing is committed: you review the result as uncommitted changes.

1. **`/spec`** on the task branch — the agent asks you for the task, interviews you (`grilling`), writes `plans/<task>/spec.md` (each item has one `check:` command), writes one acceptance test per item, has the `reviewer` agent review those tests (`test-review.md`), and proves every check fails. You reply `approved`.
2. **`/build`** in a new session on the same branch — no conversation. The agent makes each check pass test-first, with a checkpoint commit per item. A Stop hook (`skills/build/spec-check.sh`) runs every check and will not let the agent stop while one fails (at most 5 times). Up to 3 review rounds run inside `/build` (`branch-review`, analysis in the `reviewer` agent), recorded in `review.md`. At the end, `spec-check.sh --finish` resets the checkpoint commits, so every change is uncommitted. If a build stops early, run `.claude/skills/build/spec-check.sh --uncommit`.
3. **You review** the uncommitted changes and `plans/<task>/summary.md`, then commit what you keep.
4. **`/retro`** writes `plans/<task>/retro.md`: each problem with its evidence and a proposed fix to a skill or a check. Its evidence includes `plans/<task>/log.md`, which hooks write: your messages, failed tool calls and Stop-hook blocks.

The task name is the branch name. The base branch is the remote's default branch. `plans/` is gitignored except `retro.md` (`install.sh` adds the rules). The active build is recorded in `.git/harness-build*`, never committed.

The Devin copies of these files are in `.devin/`, for copying to a work machine by hand.

## Layout

```
~/claude/
├── agents/            ← symlinks into <project>/.claude/agents/
│   └── reviewer.md    ← fresh-context verifier used by /branch-review
├── templates/
│   └── AGENTS.md      ← copied (not symlinked) into new projects; CLAUDE.md links to it
├── .claude/
│   └── settings.json  ← shared permissions and hooks, symlinked into <project>/.claude/settings.json
├── .devin/            ← Devin copies of the harness, copied to a work machine by hand
└── skills/            ← symlinks into <project>/.claude/skills/
    ├── spec/ build/ retro/ branch-review/  ← the harness, run as /spec, /build, /retro, /branch-review
    ├── assistant-*/   ← always-on behavior (communication, modification policy, output)
    ├── code-*/        ← language-agnostic conventions (errors, types, style, tests)
    ├── frontend-*/    ← React/MUI/TS conventions
    └── review-*/      ← used by /branch-review
```

Each skill is a folder containing a `SKILL.md` with YAML frontmatter (`name`, `description`) and the rule body. A skill with `disable-model-invocation: true` runs only as a `/slash-command` (for example `/spec`, `/pr-message`).

## Install into a project

```bash
~/claude/install.sh /path/to/project
```

It links `skills/`, `agents/`, `.claude/settings.json` into the project's `.claude/`, creates `AGENTS.md` and the `CLAUDE.md` link if they are missing, and adds the `plans/` rules to `.gitignore`. A real (not linked) file or folder already in the project is left alone, with a note.

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

Agents live in `agents/` as markdown with YAML frontmatter (`name`, `description`, `tools`), symlinked to `<project>/.claude/agents/` by `install.sh`. The `reviewer` agent does the file analysis of `/branch-review` (step 3) in a fresh context via the Agent tool, so the findings never come from the context that wrote the code. The main context keeps the fix loop.

## AGENTS.md / CLAUDE.md

Each project gets one canonical context file, `AGENTS.md` (read natively by Devin, Codex, Cursor), with `CLAUDE.md` as a symlink to it for Claude Code. `install.sh` copies `templates/AGENTS.md` into the project if absent and creates the link. Per-project content — edit it in the project, keep it under 300 lines, prune on touch.

## Permissions

`.claude/settings.json` here is the shared permission set, symlinked into every project by `install.sh`. It allows what `/build` needs to run without prompts — reads, file edits, the test/typecheck/lint/jscpd commands, `git switch`/`checkout`/`add`/`commit` and the harness scripts. `rm`, `git push`, `git reset` and `git rebase` always ask; `aws`, dev servers, storybook and watch mode are denied. It also holds the hooks: the `/build` Stop hook, which does nothing unless a build is active, and the hooks that write `plans/<task>/log.md`. Precedence is deny > ask > allow. Machine- or project-specific additions go in the project's `.claude/settings.local.json`, which is unversioned. If a project already has a real (non-symlink) settings.json, install.sh leaves it and tells you to merge.

## Add a new slash command

Make it a skill, with `disable-model-invocation: true` so it runs only when you type it:

```markdown
---
name: <name>
description: One-line description shown in the `/` command list.
argument-hint: "[arg1] [arg2]"
disable-model-invocation: true
---
```

The arguments are in `$ARGUMENTS`.

## Reference from a skill

A slash-command skill can tell Claude to load specific skills before doing work. Example from `skills/branch-review/SKILL.md`:

```markdown
Read `AGENTS.md`, the `review-*` skills in `.claude/skills/`, and the skills that
`.claude/skills/skills-for-files.sh` names for the changed files.
```

This keeps the command body tight and the skills independently reusable.

## Caveats

- Symlinks aren't reliably watched for live changes by Claude Code. Restart the session after editing a skill to be safe.
- Skills auto-load when their `description` matches what Claude is doing. To force-load one, reference it explicitly from another skill or in the user prompt (e.g. "apply the `code-trust-the-types` skill").
