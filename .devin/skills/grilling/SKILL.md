---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Each round asks one question from the frontier: the one whose answer invalidates the most other work if it goes the other way. Wait for the user's answer before the next round.

Format a round like this example:

```
**Empty list**

The results page has no design for zero results. I would show "No results" and the search box, is that right?
```

A round is the title, one or two sentences on what part of the task this is and why it is a decision, and what you would do. The why names the rule or fact that makes this a decision. Put one decision in it. Write nothing before or after the round.

Write full, plain sentences. The round is short because it holds one decision, not because words are left out.

The question is yes/no by default. Only when you cannot pick between two or more real options yourself, ask which one instead and list them: one line per option, `a. <a few words>`, every line but the last ending in `\` so it breaks without a blank line. Never add an option to make up a number.

Start from the task, not from what you found. The question makes sense to someone who has read nothing else. No icons, no jargon.

A decision is settled only when the user gives a clear answer to it: yes, no, or one of the options, possibly with changes you can restate in one sentence. Anything else leaves it open: a question back, a doubt, "it depends", a partial answer, a correction of your premise, or a reply about something else. While it is open, stay on it. Answer their question or find the fact they need, restate the decision with what changed, and ask it again. Ask no other question until it is settled. When it is settled, restate it in one sentence as the record, then recompute the frontier.

Each settled decision reshapes the tree: it pushes the frontier outward and unblocks questions that depended on it. Recompute the frontier and ask the next round.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Find the fact before you ask the question that needs it. Never open a new question while the current one is unsettled. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
