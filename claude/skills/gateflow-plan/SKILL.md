---
name: gateflow-plan
description: >-
  Thin bridge from an already-produced requirements breakdown to Jira — tool-agnostic, see
  requirements-artifact-contract.md. Does NOT gather requirements itself: produce proposal/spec/tasks
  first (via /sdd-new or /sdd-ff if the sdd-* skill family is installed — optional, not bundled — or by
  hand matching the contract), then run this to create the matching Jira Epic + Stories. Also rolls up
  live progress against an existing epic. Invoked as "/gateflow-plan create-from-sdd <change-name>" or
  "/gateflow-plan status <EPIC-KEY>".
---

# gateflow-plan

Initial input: `$ARGUMENTS`

Never invents requirements. Depends on a **file shape**, not a specific tool — see
`_gateflow-shared/requirements-artifact-contract.md`. If the named change has no artifacts yet, it stops
and points at that contract: run `/sdd-new <change-name>` if the `sdd-*` skill family is installed, or
write `proposal.md`/`tasks.md` by hand matching the documented shape.

## Command dispatch

```
args = tokenize($ARGUMENTS)
command = args[0]
match command:
  "create-from-sdd" -> run § create-from-sdd with change_name = args[1]
  "status"          -> run § status with epic_key = args[1]
  default           -> error: usage is "create-from-sdd <change-name>" or "status <EPIC-KEY>"
```

## Preflight (both commands)

```
config = read .gateflow/config.json   # error naming the missing field if absent/incomplete
bash _gateflow-shared/adapters/planning-jira.sh ensure-account <config.planning.settings.site>
  # fails closed here if acli is on the wrong account — see planning-adapter-contract.md
```

## create-from-sdd

```
if change_name is empty: error "usage: create-from-sdd <change-name>"

# Read exactly like every sdd-* skill reads its dependencies: search then get_observation
# (search results are truncated previews, never source material) — mode from config.sddPersistence.
proposal = read_sdd_artifact(change_name, "proposal")
spec     = read_sdd_artifact(change_name, "spec")
tasks    = read_sdd_artifact(change_name, "tasks")

if proposal is null:
  stop: "No proposal found for '{change_name}'. Run /sdd-new {change_name} (if sdd-* is installed),
         or write proposal.md by hand — see requirements-artifact-contract.md."
if tasks is null:
  stop: "Proposal exists but no tasks.md yet. Run /sdd-ff {change_name} (if sdd-* is installed),
         or write tasks.md by hand — see requirements-artifact-contract.md."

content_language = config.contentLanguage or "en"   # never translates — this bridge is verbatim, always
if proposal's apparent language doesn't match content_language (plain judgment, not a library check):
  ⚠️ warn: "proposal.md reads like {detected}, but config.contentLanguage is '{content_language}' —
            tickets will carry whatever's actually in the file. Fix the source before creating tickets,
            or update config.contentLanguage if the file is right and the config is stale."
  ask: proceed anyway | abort   # never silently ship a mismatch into Jira

# Epic from the proposal's own Intent/Scope — never paraphrase beyond trimming to fit
epic_description = proposal's "## Intent" + "## Scope" sections, verbatim
epic_key = planning-jira.sh create-ticket --type Epic \
             --summary "{proposal's title}" \
             --description-file <tmpfile containing epic_description>

# One Story per tasks.md phase. Each story's description = that phase's task list +
# any spec scenarios whose domain matches the phase name (best-effort text match) —
# this is what feeds gateflow-ship's verbatim Test Plan extraction later.
for phase in tasks.phases:
  story_description = phase.tasks (as a checklist) + "\n\n## Test Plan\n" + matching_scenarios(spec, phase)
  story_key = planning-jira.sh create-ticket --type Story \
                --summary "{phase.name}" \
                --description-file <tmpfile containing story_description> \
                --parent epic_key
  record (phase.name -> story_key)

write mapping to docs/gateflow/plans/{change_name}-jira-map.md:
  "# {change_name} -> Jira\n\nEpic: {epic_key}\n\n" + one line per (phase -> story_key)

print:
  "Created {epic_key} + {N} stories. Mapping: docs/gateflow/plans/{change_name}-jira-map.md"
  "Next: /gateflow-implement <STORY-KEY> for any of the stories above."
```

`read_sdd_artifact(change_name, kind)` mirrors the exact retrieval every `sdd-*` skill already uses:

```
if config.sddPersistence == "engram":
  id = mem_search(query: "sdd/{change_name}/{kind}", project: current_project)
  if id is null: return null
  return mem_get_observation(id)   # search returns a truncated preview — always fetch the full content
elif config.sddPersistence in ("openspec", "hybrid"):
  path = "openspec/changes/{change_name}/{kind}.md"   # or specs/{domain}/spec.md for "spec"
  return read(path) if exists(path) else null
```

## status

```
if epic_key is empty: error "usage: status <EPIC-KEY>"
result = planning-jira.sh get-children-status epic_key
print "{epic_key}: {result.done}/{result.total} done"
for child in result.children:
  print "  {child.key}  {child.status}  {child.summary}"
```

## Failure handling

| Situation | Action |
|---|---|
| No `.gateflow/config.json` | Stop, name the missing file, point at `config-schema.md` |
| `ensure-account` fails | Stop with its exact message — never proceed on the wrong Jira account |
| No SDD proposal for the change | Stop, tell the user to run `/sdd-new` |
| Proposal exists, no tasks yet | Stop, tell the user to run `/sdd-ff` |
| A `create-ticket` call fails mid-loop | Stop, report which stories were already created (they're real Jira tickets — don't recreate them on retry, note in the mapping file what's already done) |
