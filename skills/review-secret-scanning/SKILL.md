---
name: review-secret-scanning
description: Secret scanning for branch reviews — grep the diff for credentials, tokens, keys, including in test fixtures. Use as part of every review regardless of project type.
---

# Secret scanning

Run on every review, regardless of project type or language.

```bash
git diff "$MERGE_BASE" "$TARGET" | grep -iE "(password|secret|api_key|token|private_key|aws_access|aws_secret|bearer )" || true
```

## Investigate every match

**Common false positives:**
- Variable names like `tokenInputRef`, `setPasswordVisible`.
- Comments mentioning "the secret is stored in Vault".
- Schema field names: `password: z.string()`.

**Real positives:**
- Hardcoded values that look like keys/tokens (long random strings near words like `key`, `secret`, `token`).
- AWS access key IDs (start with `AKIA` / `ASIA`) or secret keys (40-char base64-ish).
- JWT-looking strings (three base64 segments separated by dots).
- Connection strings with embedded credentials (`postgres://user:pass@host`).

## Test fixtures count

Even if it's "just a test fixture", flag it:
- Secrets in test fixtures end up in git history.
- Scanners can't tell test fixtures from real ones.
- The pattern leaks into production over time as people copy-paste.

Use placeholder values like `test-token-replace-me` or load from env / Vault dev mode in test setup instead.
