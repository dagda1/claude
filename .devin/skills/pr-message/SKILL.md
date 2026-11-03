---
name: pr-message
description: Write a concise, plain-English PR message to a markdown file in the tmp folder
argument-hint: "[base]"
agent: writer
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

1. Gather context with the script (do not show this in the output). It prints the house
   style, the commit subjects, the changed files, the spec goal and items, `MERGE_BASE` and
   `MESSAGE_FILE`. It does not print the full diff:

   ```bash
   .devin/skills/pr-message/pr-context.sh "$1"
   ```

2. Write the message to `MESSAGE_FILE`, following the Title rules, Bullet rules and Format
   below. Read a file's diff (`git diff <MERGE_BASE>..HEAD -- <file>`) only when the
   commits and spec do not explain that file.

   `MESSAGE_FILE` is in the system temp dir, outside the repo. Write outside the repo, **not** to a repo folder: a repo `tmp/` is gitignored and
   Cascade's write tool silently skips gitignored paths, while any non-ignored repo folder
   ends up committed by accident. The system temp dir avoids both — it's writable by the
   normal write tool in Devin and Cascade and can never be committed.

3. End the chat output with a clickable link to the file, not a bare path — a long temp path
   wraps over several lines and stops being clickable. In Devin use a `<ref_file file="..." />`
   tag; in Cascade use a markdown link (`[message](file:///...)`).

## Title rules

The title is a commit subject, not prose. The plain-English rules below apply to the bullets
only.

- Imperative mood, naming what changed: "Replace the Activity tab log viewer with a timeline".
- Under about 60 characters. No trailing full stop.
- Product nouns are fine ("Activity tab", "flow diagram", "work item"); symbol and file names are
  not.
- Never a benefit statement or a headline: not "Show a request's history as a timeline", not
  "Improved activity view".
- Match the repo's existing subjects: the "House style" part of the script output shows
  them, including whether a `feat(scope):` prefix is in use.

## Bullet rules

- Every bullet must earn its place. If a reviewer would still understand the PR without it, cut it.
- One short sentence per bullet. No sub-bullets, no clauses stacked with commas.
- Do not list every change. Give the point of the PR and only what a reviewer must know.
- Plain English, zero context assumed. No code, file paths, function names, or jargon.
- No em dashes.

## Format

```markdown
# <imperative title, commit-subject style>

- <the one main thing this PR does>
- <why, or what a reviewer must know> (only if needed)
```
