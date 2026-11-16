---
name: pr-comments
description: Review a branch and output paste-ready PR comments grouped by file, one comment per line
argument-hint: '[branch] [base]'
triggers:
  - user
allowed-tools:
  - read
  - grep
  - glob
  - exec
  - edit
---

# PR Comments

Same review as `branch-review`, but the output is PR comments a human pastes
straight into GitHub. No summary, no assessment, no changed-files list, no praise,
no "consider".

- Branch to review: `$1` (defaults to the current branch if empty)
- Base branch to compare against: `$2` (defaults to `dev` if empty)

## Steps

1. **Setup and identify changes.** Do not `git checkout`; the reviewer keeps their
   working tree. Diff against origin refs.

   ```bash
   TARGET="${1:-$(git branch --show-current)}"
   BASE="${2:-dev}"
   git fetch origin "$BASE" "$TARGET"
   MERGE_BASE=$(git merge-base origin/"$BASE" origin/"$TARGET")
   CHANGED_FILES=$(git diff --name-only "$MERGE_BASE" origin/"$TARGET" -- "*.ts" "*.tsx" "*.js" "*.jsx" "*.css" "*.json" | grep -v node_modules | grep -v "\.d\.ts$")
   ```

2. **Build the reviewer's input.** It writes the skills that apply and the numbered diff
   into chunk files and prints one batch (more only for a very large diff). Do not read the
   chunks yourself:

   ```bash
   .devin/skills/branch-review/review-bundle.sh "$MERGE_BASE" origin/"$TARGET" "${TMPDIR:-/tmp}/pr-comments-$(echo "$TARGET" | tr '/' '-')" $CHANGED_FILES
   ```

3. **Analyze each batch** in the `reviewer` subagent, one per batch, all launched in the
   same message. Give each one its chunk file paths, `MERGE_BASE` and `origin/$TARGET`.
   Tell it to read a whole file (`git show origin/"$TARGET":"$file"`) only when the diff
   context does not explain a line, and to list every suspected problem on the changed
   lines (bugs, skill violations and duplication) and drop nothing. Merge their lists:
   where two reviewers report the same problem on the same line, keep one.

4. **Test each suspected problem** against the codebase. For a bug, check callers and
   existing patterns, then name the input, the code path and the wrong result; drop it
   only when this shows the behaviour is correct. For a skill violation, confirm the
   changed line breaks the rule as the skill words it; drop it only when it does not.

5. **Check for duplication.** For every function, hook, component, constant, schema and
   column definition the diff adds, search `origin/$TARGET` for one that already does the
   same job (`git grep -n <term> origin/"$TARGET" -- apps packages`), searching by what it
   does as well as by its name. Also look for the same logic written twice inside the
   diff. Read both copies before keeping one: drop it when they differ in behaviour, not
   just in names. Each kept duplicate is a comment on the added copy that names the
   existing one by path and symbol.

6. **Write the PR comments to a markdown file** in the **system temp dir** (outside the
   repo working tree), named after the branch with `/` replaced by `-`:

   ```bash
   COMMENTS_FILE="${TMPDIR:-/tmp}/pr-comments-$(echo "$TARGET" | tr '/' '-').md"
   ```

   Write outside the repo, **not** to a repo folder: a repo `tmp/` is gitignored and
   Cascade's write tool silently skips gitignored paths, while any non-ignored repo
   folder ends up committed by accident. The system temp dir avoids both — it's writable
   by the normal write tool in Devin and Cascade and can never be committed.

   In chat, give only a clickable link to the file and the comment count. A bare temp path
   wraps over several lines and stops being clickable: in Devin use a
   `<ref_file file="..." />` tag; in Cascade use a markdown link (`[comments](file:///...)`).

## Rules

- Comment on everything `branch-review` would report on the changed lines: bugs,
  performance defects, skill violations and duplication (step 5).
- The comments file is the output the user asked for. Reply-brevity rules apply to
  the chat message only, never to which comments go in the file.
- One comment, one line. Never a range or multiple line numbers per comment.
- Only comment on lines this PR changed. Never invent a line in an unchanged file.
- Every comment states why, in one sentence: the wrong behaviour or the rule broken.
  Never code alone.
- Every comment stands alone. The reader sees one comment on one line of the PR and
  nothing else: not the other comments, not this review, not the skills. So:
  - Never point at another comment: no "same as above", "see L42", "as noted", "also
    here", "like the previous one". When a mistake repeats, each line gets its own full
    comment.
  - Never mention the review's own workings: reviewers, batches, chunks, findings,
    rounds, skill names, "the rule", "the pattern", "the project standard".
  - Name every function, component, file and value the reader needs by path or symbol,
    and state the rule itself rather than where it is written.
- One problem, one comment. Before writing the file, read every comment against the
  others and merge any two that describe the same problem on the same line.
- Add a code snippet after that sentence whenever code makes the fix clearer. Keep it
  to the few lines that change; if the fix is too large to show that way, the sentence
  carries it alone.
- No em dashes.

## Output

A markdown file, grouped by file, comments in line order. Each is `L<line>`, then the
sentence that says why, then a code snippet when one helps. Only code goes in a fenced
block, with a language tag (`ts`, `tsx`); the sentence stays plain text, never fenced.

````
# PR comments: <branch>

## apps/frontend/src/pages/Foo/Bar.tsx

L42

`onStart()` runs on every render because it is called, not passed, so the flow starts
before the user clicks.

```ts
onClick={onStart}
```

L67

Guard `items` before indexing, this throws on first render when empty.
````

If a real problem's fix lives in an unchanged file, add one comment under `## General`
at the end (no line number). Omit the heading if empty. If there are no problems, write
one line in the file and say so in chat.

## Re-runs

When asked to check again, re-review and rewrite the same file with the outstanding
list only. Drop comments that are now fixed, keep what is still unresolved. Every
comment in the rewritten file still stands alone: never "still not fixed" or "as in the
last run".
