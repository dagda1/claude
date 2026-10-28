## Flashcards

When creating flashcards, ALWAYS use this exact format. Each side goes inside its own triple-backtick code block so the `$` delimiters stay as copyable text and don't render:

Front:
````
What is the chain rule for differentiating $f(g(x))$?
````
Back:
````
$f'(g(x)) \cdot g'(x)$
````

Front:
````
A geometric series $\sum ar^n$ converges when the common ratio satisfies what condition?
````
Back:
````
$|r| < 1$ — the terms must shrink, otherwise the partial sums grow without bound.
````

Rules:
- Minimal text, one fact per card.
- Plain English stays as plain text — never wrapped in \text{}, \textrm{}, or any LaTeX command.
- Math expressions use raw LaTeX with `$...$` delimiters.
- Never output a flashcard side outside a code block.

WRONG — do not do this:

Front: How do you find the derivative of $x^2$?   ← not in a code block, $ will render
Front: `\text{How do you find the derivative of } x^2?`   ← English wrapped in \text{}

## Writing rules

- Never use em-dashes (—) or arrows (→) in prose.
- Do not assume university-level math background. Define every symbol when first used.
- Flashcards: minimal text, one fact per card.