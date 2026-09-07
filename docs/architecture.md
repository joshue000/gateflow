# gateflow architecture

## What this is

A personal SDLC workflow: plan → implement → review (two-gate quality lock) → ship → docs. Built to be
genuinely agnostic of code host and project-tracking tool — a config file picks the backend, the
workflow logic never hardcodes one.

## The one rule that keeps it agnostic

No skill talks to GitHub or Jira directly. Every skill calls a small, named **adapter operation**
(`vcs-github.sh <op>`, `planning-jira.sh <op>`). Adding Bitbucket or Notion later means writing a new
adapter script with the same operation names — zero edits to any `SKILL.md`.

```
skills (gateflow-plan / -implement / -review / -ship / -docs)
        │  calls named ops only, never a raw `gh`/`acli` command
        ▼
adapter contract (vcs-adapter-contract.md, planning-adapter-contract.md)
        │  one concrete script per backend
        ▼
adapters/vcs-github.sh · adapters/planning-jira.sh
```

## PE reviewers are generated, not a fixed roster

`pe-typescript`/`pe-react` are hand-written instances of `pe-agent-template.md`'s shape, not a closed
list. `gateflow-init` (during setup) and `gateflow-init add-pe <stack>` (later, standalone) generate a
new specialist for any stack with no existing PE, grounded in real files from the target project when
available. `pe-general` is the fallback for anything nobody's generated a specialist for yet — never a
permanent ceiling, just the default until someone asks for better.

## Where things live

- `~/.claude/skills/gateflow-*` and `~/.claude/agents/*` — **symlinks**, required by Claude Code to be
  exactly there for global discovery. Never edit through the symlink; edit the source below.
- `~/Projects/personal/gateflow/claude/` — the actual source. `install.sh` re-links it into `~/.claude/`.
- `.gateflow/config.json` — lives in *each project* using gateflow, not here. Picks the backends and
  carries project-specific settings (owner/repo, Jira site, PE routing, reviewers).

## Requirements input is a documented contract, not a hard tool dependency

`gateflow-plan` doesn't gather requirements itself, and it doesn't depend on any specific tool to
produce them — it depends on files matching `_gateflow-shared/requirements-artifact-contract.md`
existing at a documented location. The `sdd-propose`/`sdd-spec`/`sdd-design`/`sdd-tasks` skill family
(MIT, orchestrated via `/sdd-new`/`/sdd-ff`) is the easiest way to produce them correctly — but it's an
**optional, separately-installed convenience, not bundled with gateflow**. No `sdd-*` on the machine?
Write `proposal.md`/`tasks.md` by hand matching the contract, or use a different tool entirely —
`gateflow-plan` reads a file shape, it never calls an `sdd-*` skill directly.

## Documents in this repo

| File | Purpose |
|---|---|
| `claude/skills/_gateflow-shared/vcs-adapter-contract.md` | The VCS operation contract + GitHub mapping |
| `claude/skills/_gateflow-shared/planning-adapter-contract.md` | The Planning operation contract + Jira mapping |
| `claude/skills/_gateflow-shared/config-schema.md` | Human-readable `.gateflow/config.json` field reference |
| `claude/skills/_gateflow-shared/tier-classifier.md` | Review depth classification |
| `claude/skills/_gateflow-shared/gate-model.md` | Two-gate lock/override mechanics |
| `claude/skills/_gateflow-shared/pr-template.md` | PR description sections + sources |
| `claude/skills/_gateflow-shared/requirements-artifact-contract.md` | The file shape `gateflow-plan` reads — decouples it from any specific requirements tool |
| `claude/skills/_gateflow-shared/claude-md-template.md` | Starter `CLAUDE.md` skeleton `gateflow-init` fills in |
| `claude/skills/_gateflow-shared/claude-md-suggestions.md` | Tagged catalog of optional stack-specific principles `gateflow-init` offers |
| `claude/skills/_gateflow-shared/universal-principles.md` | SOLID/DRY/YAGNI/testing-pyramid baseline, offered only when the global config doesn't already cover it |
| `claude/skills/_gateflow-shared/pe-agent-template.md` | The five-pass skeleton `gateflow-init`/`add-pe` fills in to generate a new PE reviewer for any stack |
| `schema/config.schema.json` | Machine-checkable config schema |
| `test/e2e-checklist.md` | End-to-end verification steps |

## Language policy

Two buckets, and only one of them is ever configurable — don't confuse them.

**Always English, every project, no exception**: code, comments, commits, branch names, PR titles,
config keys, and `design.md` (pure technical reasoning — architecture decisions, file changes,
interfaces — never quoted verbatim into a ticket, so there's nothing downstream that needs it in
another language).

**Configurable per project via `contentLanguage`**: `proposal.md`/`spec.md`/`tasks.md` (they feed Jira
tickets verbatim through `gateflow-plan` — author them directly in `contentLanguage`, no translation
step, no second copy to keep in sync) and any `gateflow-docs` output aimed at the project's actual
users/stakeholders. Some projects will set this to `"en"` because their audience reads English —
that's not a special case, it's just `contentLanguage` matching code's language for that project.
Default is `"en"` when the field is omitted.

Separately: Jira's own workflow status *names* (To Do/In Progress/Done) are whatever the Jira site's
language setting produced when the workflow was created — this is **not** `contentLanguage` and gateflow
doesn't control it. Never assume it, verify against a real ticket (`acli jira workitem create` a
throwaway one, check `status.name`, delete it). A project rename or a site language-setting change can
silently flip this out from under a previously-verified `jiraStatusCandidates` value.

## Adding a second backend later

1. Write `adapters/<kind>-<name>.sh` implementing every op in the relevant contract doc.
2. Nothing else changes — skills read `.gateflow/config.json`'s `backend` field and shell out to
   whichever adapter script matches.
