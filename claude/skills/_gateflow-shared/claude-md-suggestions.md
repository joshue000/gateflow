# CLAUDE.md suggestion catalog

Candidate engineering principles `gateflow-init` offers during setup — never inserted without the
user accepting each one. Each entry: `id`, `tags` (matched against the stack/answers from init's Q&A;
`always` matches every project), the text to insert verbatim if accepted.

These are original phrasing of generic, reusable engineering ideas — not copied from any specific
codebase's CLAUDE.md. Extending this file never requires touching `gateflow-init/SKILL.md`'s logic.

---

### `monorepo-task-runner` — tags: `monorepo`

Prefer the monorepo task runner (Turborepo/Nx/etc.) over invoking a workspace's package script
directly. It handles dependency ordering, parallelism, and caching — calling the script directly
bypasses the cache and can produce stale output.

### `docker-build-root` — tags: `monorepo`, `docker`

Docker builds run from the repo root, not the app directory, whenever workspace packages depend on
hoisted `node_modules` — they aren't self-contained.

### `readme-vs-claude-md` — tags: `always`

README is for onboarding: runnable commands, setup steps. CLAUDE.md is for architectural context:
patterns, decisions, the "why." When a command changes, update the README. When a pattern or decision
changes, update CLAUDE.md. Don't let one drift into the other's job.

### `update-triggers` — tags: `always`

State explicitly, in this file, what changes should trigger an update to it (a new module, a changed
convention, a new major architectural concern). A CLAUDE.md with no stated update triggers quietly goes
stale — nobody remembers to revisit it.

### `never-edit-generated` — tags: `codegen`

Files produced by a build step (routes from decorators, types from a schema, an OpenAPI spec) are
outputs, not sources. Never hand-edit them — document what the real source of truth is instead.

### `centralized-error-handling` — tags: `backend`

Handlers/controllers throw typed errors; they don't catch-and-respond locally. Centralize error
shaping and logging in one place (middleware, an exception filter) so every endpoint behaves
consistently instead of reinventing error responses per route.

### `local-dev-stubs` — tags: `backend`, `cloud-deps`

Inject null/local implementations for cloud dependencies (queues, object storage, external services)
automatically in local/test environments, so tests and local runs never need real cloud credentials to
pass.
