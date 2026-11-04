---
name: pr-comments
description: Review a branch and output paste-ready PR comments grouped by file, one comment per line, bugs only
argument-hint: "[branch] [base]"
disable-model-invocation: true
---

# PR Comments

Same review as `branch-review`, but the output is PR comments a human pastes
straight into GitHub. No summary, no assessment, no changed-files list, no praise,
no "consider".

Arguments, in order: `$ARGUMENTS`

- Branch to review: the first argument (defaults to the current branch if empty)
- Base branch to compare against: the second argument (defaults to the remote's default
  branch if empty)

## Steps

1. **Setup and identify changes.** Do not `git checkout`; the reviewer keeps their
   working tree. Diff against origin refs.

   ```bash
   ARG_BRANCH="<first argument, or empty>"
   ARG_BASE="<second argument, or empty>"
   TARGET="${ARG_BRANCH:-$(git branch --show-current)}"
   BASE="${ARG_BASE:-$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')}"
   git fetch origin "$BASE" "$TARGET"
   MERGE_BASE=$(git merge-base origin/"$BASE" origin/"$TARGET")
   CHANGED_FILES=$(git diff --name-only "$MERGE_BASE" origin/"$TARGET" -- "*.ts" "*.tsx" "*.js" "*.jsx" "*.css" "*.json" | grep -v node_modules | grep -v "\.d\.ts$")
   ```

2. **Build the reviewer's input.** It writes the skills that apply and the numbered diff
   into chunk files and prints one batch (more only for a very large diff). Do not read the
   chunks yourself:

   ```bash
   .claude/skills/branch-review/review-bundle.sh "$MERGE_BASE" origin/"$TARGET" "${TMPDIR:-/tmp}/pr-comments-$(echo "$TARGET" | tr '/' '-')" $CHANGED_FILES
   ```

3. **Analyze each batch** in the `reviewer` subagent (the Agent tool, `subagent_type: reviewer`), one per batch, all launched in the
   same message. Give each one its chunk file paths, `MERGE_BASE` and `origin/$TARGET`.
   Tell it to read a whole file (`git show origin/"$TARGET":"$file"`) only when the diff
   context does not explain a line, and to list every suspected bug on the changed lines
   and drop nothing. Merge their lists.

4. **Test each suspected bug** against the codebase: check callers and existing
   patterns, then name the input, the code path and the wrong result. Drop it only
   when this shows the behaviour is correct. Keep it when the wrong result is shown.

5. **Write the PR comments to a markdown file** in the **system temp dir** (outside the
   repo working tree), named after the branch with `/` replaced by `-`:

   ```bash
   COMMENTS_FILE="${TMPDIR:-/tmp}/pr-comments-$(echo "$TARGET" | tr '/' '-').md"
   ```

   Write outside the repo, **not** to a repo folder, so it is never committed by accident.

   In chat, give only a clickable link to the file and the comment count. A bare temp path
   wraps over several lines and stops being clickable. Use a markdown link
   (`[comments](file:///...)`).

## Rules

- Bugs only: wrong behaviour, crash, regression, broken logic, security, and clear
  performance defects (needless re-renders, work in render/loops that should be
  memoised or hoisted, O(n^2) over real data). Flag a skill violation only when
  breaking it changes runtime behaviour or produces a defect, never for pure
  style/naming/formatting.
- The comments file is the output the user asked for. Reply-brevity rules apply to
  the chat message only, never to which bugs go in the file.
- One comment, one line. Never a range or multiple line numbers per comment.
- Only comment on lines this PR changed. Never invent a line in an unchanged file.
- Every comment states why, in one sentence: the wrong behaviour or the rule broken.
  Never code alone.
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

If a real bug's fix lives in an unchanged file, add one comment under `## General`
at the end (no line number). Omit the heading if empty. If there are no bugs, write
one line in the file and say so in chat.

## Re-runs

When asked to check again, re-review and rewrite the same file with the outstanding
list only. Drop
comments that are now fixed, keep what is still unresolved.
