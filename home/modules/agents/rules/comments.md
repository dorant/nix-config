# Code Comments

## Comments describe the code, not the change

Write comments for someone reading the code later, with no knowledge of the commit
that introduced it. Describe what the code does and why. Do not describe how it
differs from what was there before.

Avoid in comments:

- References to the change itself: "now handles", "no longer", "previously",
  "this fix", "added to support", "changed so that"
- Positional references to other code that may move: "unlike the branch above",
  "not covered by the handling below"
- Justifying the edit to a reviewer rather than informing a reader

Examples:

- Bad: `// These are not covered by the CallExpr handling above, so mark them here.`
- Good: `// Atomic builtins are AtomicExpr, not CallExpr, and may write through their operands.`
- Bad: `// Conservatively mark all operands so that such parameters are not made const.`
- Good: `// The 'expected' operand receives the old value when the exchange fails.`
- Bad: `// Now also checks the weak variant.`
- Good: `// Both the strong and weak variants write to 'expected'.`

State facts a future reader needs: invariants, non-obvious constraints, and where a
rule comes from. Prefer naming one concrete case over enumerating all of them, and
do not restate what the code plainly does. Two lines is usually enough.

## Where change descriptions belong

Commit messages, pull request descriptions, and changelog or release-note files.
Those should describe the change; code comments should not.

## Known limitations

When code intentionally does less than a reader might expect, say so and give the
reason. Keep it to a statement of fact about the behaviour. Only add a `TODO` when
the gap is genuinely intended to be fixed and the file already uses that
convention.
