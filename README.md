# gateflow

A personal SDLC workflow for Claude Code — plan → implement → review (two-gate quality lock) → ship →
docs. Genuinely agnostic of code host and project-tracking tool: a per-project `.gateflow/config.json`
picks the backend, the workflow logic never hardcodes one. MVP ships with GitHub (via `gh`) and Jira
(via `acli`); adding another backend later is a new adapter script, not a rewrite.

Full design: [`docs/architecture.md`](docs/architecture.md). Field reference for the config file:
[`claude/skills/_gateflow-shared/config-schema.md`](claude/skills/_gateflow-shared/config-schema.md).

## Install

```bash
./install.sh
```

Symlinks `claude/skills/*` and `claude/agents/*.md` into `~/.claude/{skills,agents}` — globally
available across every project on this machine. Re-run after any edit here; it's idempotent.

## Requires

- [`gh`](https://cli.github.com) — `brew install gh && gh auth login`
- `acli` (Atlassian CLI) — `acli jira auth login --site <your-site>`
- `jq`
- **Optional**, only for `gateflow-plan create-from-sdd`: the `sdd-propose`/`sdd-spec`/`sdd-design`/
  `sdd-tasks` skill family (MIT, `~/.claude/skills/sdd-*`, not bundled). Don't have it? Write
  `proposal.md`/`tasks.md` by hand — see `requirements-artifact-contract.md`. Everything else in
  gateflow works with zero dependency on this.

## Use in a project

1. `/gateflow-init` — Q&A that writes `.gateflow/config.json`, generates a specialized PE reviewer for
   any stack that doesn't have one yet, and drops a starter `CLAUDE.md` (referencing gateflow instead
   of duplicating its rules, plus optional engineering principles you pick from a catalog). Or drop
   `.gateflow/config.json` by hand — see `config-schema.md`. Add a PE later, standalone, with
   `/gateflow-init add-pe <stack>`.
2. `/sdd-new <change>` (or `/sdd-ff`) to get requirements → design → tasks — gateflow doesn't reimplement
   this, it consumes the result.
3. `/gateflow-plan create-from-sdd <change>` — pushes the task breakdown into Jira as an Epic + Stories.
4. `/gateflow-implement <TICKET-KEY>` → `/gateflow-review` → `/gateflow-ship`.
5. `/gateflow-docs <what to document>` whenever, standalone.

## Deferred work

[`TODO.md`](TODO.md) — things deliberately not built yet, and why. Check there before re-deciding
something already reasoned through.

## Verify

[`test/e2e-checklist.md`](test/e2e-checklist.md) — run through it once after Step 0 setup on a real toy
project before trusting this on real work.
