# Requirements artifact contract

`gateflow-plan create-from-sdd` doesn't depend on any specific tool — it depends on files matching this
shape existing at a documented location. The `sdd-propose`/`sdd-spec`/`sdd-design`/`sdd-tasks` skill
family (optional, MIT, `~/.claude/skills/sdd-*`, not bundled with gateflow) happens to be the easiest
way to produce them correctly, and `/sdd-new`/`/sdd-ff` are convenient meta-commands for chaining them —
but nothing here requires that specific family. Write these by hand, or with a different tool, and
`gateflow-plan` works exactly the same.

## Location (per `config.sddPersistence`)

| Mode | Where |
|---|---|
| `openspec` | `openspec/changes/{change-name}/{proposal,spec,design,tasks}.md` — plain files |
| `engram` | topic keys `sdd/{change-name}/{proposal,spec,tasks}` (search → get_observation) |
| `hybrid` | both |

## Shape `gateflow-plan` actually reads

**`proposal.md`** — must have a `## Intent` and a `## Scope` heading. Their content (verbatim) becomes
the Jira Epic's description.

```markdown
# Proposal: {Title}
## Intent
{why this change}
## Scope
### In Scope
- ...
```

**`tasks.md`** — must have `## Phase N: {name}` headings, each with a checklist. One Story per phase;
the checklist becomes that Story's task list.

```markdown
## Phase 1: {name}
- [ ] 1.1 {concrete action}
- [ ] 1.2 {concrete action}
```

**`spec.md`** — optional but recommended; `#### Scenario: {name}` Given/When/Then blocks. Scenarios
whose text loosely matches a phase's name get pulled into that phase's Story description as its Test
Plan (feeds `gateflow-ship`'s verbatim Test Plan extraction downstream).

```markdown
#### Scenario: {name}
- GIVEN {precondition}
- WHEN {action}
- THEN {outcome}
```

**`design.md`** — never read by `gateflow-plan`. Not part of this contract at all; it exists for the
codebase's own technical record, not for ticket content.

## What this buys you

Don't have `sdd-*` installed? Write `proposal.md` and `tasks.md` by hand matching the shapes above,
drop them at the `openspec` path for your change name, and `create-from-sdd` works identically —
`gateflow-plan` cannot tell the difference between a file `sdd-tasks` wrote and one you typed yourself.
