---
name: assistant-modification-policy
description: Code modification policy for the assistant — only modify code when explicitly asked, ask before acting on complaints, never add unrequested features or comments. Always relevant.
---

# Code modification policy

## Don't modify unprompted

- **Do NOT modify code unless explicitly asked.** "What do you think of this?" is not a request to change it.
- When the user complains about something, **ask** if they want it changed before acting.
- Don't add features that weren't requested.
- Don't add code comments (see `code-style-defaults`).

## Match the scope of the request

- A bug fix doesn't need surrounding cleanup.
- A one-shot operation doesn't need a helper abstraction.
- A rename doesn't need to also reformat the file.

If you spot related improvements while doing the requested work, flag them in your reply — don't bundle them silently.

## Don't add what isn't asked for

- No error handling for cases that can't happen.
- No fallbacks for scenarios that the type system rules out.
- No feature flags unless requested.
- No backwards-compatibility shims unless the user said so — change the code directly.
