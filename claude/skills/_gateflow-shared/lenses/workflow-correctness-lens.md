# Lens: workflow-correctness

Folded into every dispatched agent's prompt as shared attention text — never spawned as a separate
reviewer. Applies during Pass 4 (Adversarial Re-read).

**Focus**: does the change actually satisfy the ticket's acceptance criteria end-to-end, not just "does
each function individually look right."

Key probes:
- Trace one full request/user path through the diff — does it actually reach the new behavior, or does
  an earlier branch/guard short-circuit it?
- Does an edge case in the ticket's scenarios (empty input, concurrent access, partial failure) actually
  get handled, or only the happy path?
- If this change touches a multi-step process, can it be left in a half-done state by a crash/retry?
- Does the diff's test coverage actually exercise the scenario it claims to, or does it mock away the
  exact thing being tested?
