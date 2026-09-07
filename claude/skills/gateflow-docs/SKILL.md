---
name: gateflow-docs
description: >-
  On-demand documentation authoring — README sections, ADRs outside the SDD change trail, API reference.
  Dispatches the tech-writer agent. Does not duplicate sdd-archive (which already syncs a completed SDD
  change's specs into the permanent spec set). Invoked as "/gateflow-docs <what to document>".
---

# gateflow-docs

Initial input: `$ARGUMENTS`

## Scope check

```
if $ARGUMENTS describes syncing a completed SDD change's specs into the permanent spec set:
  redirect: "That's sdd-archive's job — run /sdd-archive <change-name> instead."

else:
  proceed — this covers README, ADRs outside the SDD trail, API reference, or anything else
  documentation-shaped that isn't already owned by an SDD artifact
```

## Language

```
# ADRs and pure technical/API reference (developer audience) are ALWAYS English — same bucket as
# design.md, never governed by contentLanguage. A user guide, feature doc, or anything this project's
# actual end users would read follows config.contentLanguage. If $ARGUMENTS doesn't make the audience
# obvious, ask rather than guess — this is the same mistake gateflow-plan was built to catch.
if audience is unclear from $ARGUMENTS:
  ask: "developer-facing (English) or end-user-facing (config.contentLanguage = '{contentLanguage}')?"
doc_language = "en" if developer-facing else (config.contentLanguage or "en")
```

## Dispatch

```
Agent(subagent_type: "tech-writer", prompt:
  "Authoring mode. Task: {$ARGUMENTS}. Write in {doc_language}.
   Read the actual code this will describe before writing anything — never invent behavior.
   If something is genuinely ambiguous from the code alone, say so rather than guessing."
)
```

## Review

```
present the draft to the user before writing it to disk:
  ask: accept | revise (loop, feedback goes back to the agent) | discard
never write documentation to disk without this confirmation — a wrong doc is worse than no doc
```

## Failure handling

| Situation | Action |
|---|---|
| Request is actually an SDD-archive task | Redirect to `/sdd-archive`, don't duplicate its work |
| tech-writer flags genuine ambiguity | Surface it to the user as a question, don't let the draft guess |
