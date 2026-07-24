---
name: pr-message
description: Write a concise, plain-English PR message to a markdown file in the tmp folder
argument-hint: "[base]"
triggers:
  - user
allowed-tools:
  - read
  - grep
  - glob
  - exec
---

# PR Message

Write a concise PR message in plain English to a markdown file in the tmp folder.

- Base branch to diff against: `$1` (defaults to `dev` if empty)

## Steps

1. Gather context (do not show this in the output):

   ```bash
   BASE="${1:-dev}"
   git fetch origin $BASE
   MERGE_BASE=$(git merge-base origin/$BASE HEAD)
   git log --oneline $MERGE_BASE..HEAD
   git diff --stat $MERGE_BASE..HEAD
   git diff $MERGE_BASE..HEAD
   ```

2. Write the message to `/tmp/pr-message.md`.

## Output rules

- **Plain English bullet points.** No itemised list of code changes.
- **Assume the reader has zero context** about the work — explain what changed and why in terms a teammate who never saw the code would understand.
- **No code, file paths, function names, or jargon** that only someone who did the work would recognise.
- **Concise** — a short title line plus a handful of bullets. Cut anything that isn't needed to understand the change.

## Format

```markdown
# <short plain-English title>

- <what changed, in plain terms>
- <why it changed / what problem it solves>
- <anything a reviewer should know>
```
