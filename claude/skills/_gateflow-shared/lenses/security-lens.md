# Lens: adversarial-security

Folded into every dispatched agent's prompt as shared attention text — never spawned as a separate
reviewer. Applies during Pass 4 (Adversarial Re-read) alongside the agent's own stack-specific checks.

**Focus**: could this diff be misused, not just does it work as intended.

Key probes:
- Does any new input reach a query, shell command, or template without validation/escaping?
- Does any new code path skip an auth/authz check that a sibling path enforces?
- Are secrets, tokens, or credentials ever logged, committed, or returned in a response body?
- Does error handling leak internal details (stack traces, file paths, query text) to a caller?
- Does a new dependency or config change widen an attack surface (new open port, new public endpoint,
  loosened CORS/CSP)?
