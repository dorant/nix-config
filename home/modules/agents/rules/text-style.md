# Text Style

## No Unicode arrows

Do not use Unicode arrow characters (`→`, `←`, `↔`, `⇒`, etc.) in text, code comments, markdown, or log output.
Use plain ASCII instead:

- `→` → write `to`, `->`, or rephrase
- `←` → write `from` or `<-`
- `⇒` → write `implies`, `means`, or `=>`

Examples:

- Bad: `scaled 1→23 shards`
- Good: `scaled 1 to 23 shards`
- Bad: `conc-profile-1→4shards`
- Good: `conc-profile-1 to 4shards`
- Bad: `node A → node B`
- Good: `node A -> node B`

## No en dashes

Do not use Unicode en dash characters. Use plain ASCII instead.

- `–` (en dash) write `-` or `to` for ranges

Examples:

- Bad: `values 10–20`
- Good: `values 10-20` or `values 10 to 20`

## No em dashes

Do not use em dashes (`—` or `--`) as a writing device. They interrupt the reader's flow and are a lazy way to connect thoughts. Use proper punctuation instead.

Replacements:

- Two independent sentences: use a period.
- Loosely connected sentences: use a semicolon.
- Short interrupting phrases: use commas.
- Longer parenthetical remarks: use parentheses.
- Trailing off: use an ellipsis (in ASCII `...`).
- Or just remove the interrupting phrase entirely.

Examples:

- Bad: `The operator handles this automatically — even during scaling.`
- Good: `The operator handles this automatically, even during scaling.`
- Bad: `This is important — do not skip it — or the test will fail.`
- Good: `This is important. Do not skip it, or the test will fail.`
- Bad: `The rebalancer — which runs every 2s — migrates slots in batches.`
- Good: `The rebalancer (which runs every 2s) migrates slots in batches.`

This keeps output readable in terminals, log files, and tools that don't render Unicode well.
