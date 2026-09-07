# Lens: docs-clarity

Folded into `tech-writer`'s prompt whenever a diff touches documentation (README, `*.md`, doc comments)
— inside `gateflow-review` automatically, or standalone via `gateflow-docs`.

**Focus**: would someone with no prior context on this change understand it from the doc alone, and does
the doc match what the code actually does.

Key probes:
- Does every claim in the doc correspond to real, current code — not aspirational or stale behavior?
- Could a new reader follow a setup/usage instruction verbatim and have it actually work?
- Is there unexplained jargon, an acronym never expanded, or a term used two different ways?
- Does the doc's structure match its purpose (a README answers "how do I use this," an ADR answers "why
  did we choose this") rather than mixing both?
- Is anything asserted that the diff doesn't actually verify — a doc must never invent behavior the code
  doesn't have.
