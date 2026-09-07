# CLAUDE.md starter template

`gateflow-init` fills `{PROJECT_NAME}` / `{STACK_SUMMARY}` / `{UNIVERSAL_PRINCIPLES}` /
`{ACCEPTED_PRINCIPLES}` and writes the result as the project's `CLAUDE.md`. Always English — this file
is developer/AI-facing, same bucket as `design.md`, never governed by `contentLanguage`.

`{UNIVERSAL_PRINCIPLES}` is conditional — see `gateflow-init/SKILL.md`'s detection step. If the user's
global Claude Code config already appears to cover SOLID/DRY/YAGNI/testing-pyramid, this section (and
the whole `universal-principles.md` read) is skipped entirely — `"*(covered by your global config)*"`.
Only inject the baseline when it isn't already covered somewhere; never duplicate it.

```markdown
# {PROJECT_NAME}

{STACK_SUMMARY}

## Workflow — owned by gateflow, don't redefine it here

This project's SDLC runs through `gateflow` (`/gateflow-implement`, `/gateflow-review`,
`/gateflow-ship`, `/gateflow-plan`, `/gateflow-docs`). Branch naming, commit format, the review gate
model, and PR structure are enforced there — see `.gateflow/config.json` and, for the mechanism itself,
the `gateflow` repo's `docs/architecture.md`. **Do not restate or re-derive these rules here** — if one
needs to change, change it in `gateflow`, not in prose in this file. Two places disagreeing on a rule
is worse than one place being briefly wrong.

## Engineering Principles

{UNIVERSAL_PRINCIPLES}

{ACCEPTED_PRINCIPLES}

## Project-Specific Context

*(Fill this in yourself — gateflow can't know it.)* Business domain concepts, feature-specific
conventions, non-obvious architectural decisions unique to this codebase. This is the one section
`gateflow-init` deliberately leaves blank.

## Keeping This File Current

Update the section above when a domain concept, a non-obvious decision, or a "why" changes. If a
command or setup step changes, that's the README's job, not this file's.
```
