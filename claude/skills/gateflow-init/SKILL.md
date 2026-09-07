---
name: gateflow-init
description: >-
  Bootstraps a new project to use gateflow — asks a short Q&A (with suggestions, not blank questions)
  to write .gateflow/config.json, verifies Jira status names against a real throwaway ticket rather than
  assuming, generates a specialized PE reviewer agent on demand for any stack that doesn't have one yet,
  and drops a starter CLAUDE.md that references gateflow instead of duplicating its rules, with optional
  engineering principles (universal baseline + stack-specific catalog) offered, never forced. Invoked as
  "/gateflow-init" (full setup) or "/gateflow-init add-pe <stack>" (generate one PE later, standalone).
---

# gateflow-init

Reference: `_gateflow-shared/config-schema.md`, `_gateflow-shared/claude-md-template.md`,
`_gateflow-shared/claude-md-suggestions.md`, `_gateflow-shared/universal-principles.md`,
`_gateflow-shared/pe-agent-template.md`.

## Command dispatch

```
args = tokenize($ARGUMENTS)
match args[0]:
  "add-pe" -> run § add-pe with stack = rest of args (ask if blank)
  default  -> run the full init flow, Phase 0 through End ($ARGUMENTS ignored — it's Q&A-driven)
```

## Phase 0 — Don't clobber

```
if .gateflow/config.json exists:
  ask: overwrite | abort
  if abort: exit
```

## Phase 1 — VCS

```
prefill = parse `git remote get-url origin` for an owner/repo (github.com only — this MVP's only backend)
ask to confirm the prefill, or provide owner/repo directly if no remote/prefill
ask defaultBaseBranch (default "main")
```

## Phase 2 — Planning (Jira)

```
ask: Jira site (e.g. yoursite.atlassian.net), project key
bash _gateflow-shared/adapters/planning-jira.sh ensure-account <site>
if it fails:
  🛑 show its exact message — tell the user to `acli jira auth login` / `auth switch` first, then retry
  do NOT proceed past this without a passing ensure-account
```

## Phase 3 — Content language

```
ask: "What language do this project's actual end users/stakeholders speak?" (default "en")
→ contentLanguage
note (don't ask, just state): code/comments/commits/design.md/this CLAUDE.md stay English regardless
```

## Phase 4 — SDD persistence

```
recommend "openspec" — real files, git-tracked, cheap to re-read (see config-schema.md's reasoning)
ask to confirm or override to engram | hybrid
→ sddPersistence
```

## Phase 5 — Stack + PE routing (generate specialists on demand)

```
ask: "What's the stack?" (free text — e.g. "NestJS backend, React frontend, Go worker")

for each named technology:
  known_match = an existing ~/.claude/agents/pe-*.md whose name/description matches it
                (aliases: node/nestjs/express/tsoa → pe-typescript; react → pe-react; etc.)
  if known_match:
    add its pathRule (ask for a directory hint, e.g. "apps/api")
  else:
    🟡 offer: "No specialized PE for {tech} yet — generate one now (recommended) using the standard
              five-pass template, or route these files to pe-general instead?"
    if generate: run § Generate a PE with stack = {tech}; add its pathRule
    else:        no rule added — {tech}'s files fall to pe-general, the fallback

peRoster = { fallback: "pe-general", pathRules: [...] }   # pre-existing + newly generated, in order

stack_tags = tags implied by the stack answer, used again in Phase 9:
  "monorepo" if the answer mentions a monorepo / multiple apps/packages
  "docker" if it mentions Docker
  "codegen" if it mentions tsoa/GraphQL codegen/schema-generated types/OpenAPI generation
  "backend" if any backend framework was named
  "cloud-deps" if it mentions a cloud provider or managed service (queues, object storage, etc.)
```

### § Generate a PE (shared — called from Phase 5 and from `add-pe`)

```
read _gateflow-shared/pe-agent-template.md
if the project already has code in the relevant directory:
  read a handful of real files there — ground the five-pass specifics in the actual codebase,
    never generic knowledge alone, per the template's Generation checklist
fill the template's bracketed sections with genuine {stack}-specific architecture/quality/security
  knowledge (never generic filler, never transplant another stack's specifics)
write ~/.claude/agents/pe-{stack}.md
✅ pe-{stack} generated — tools stay Read/Grep/Glob/Bash (reviewer, not author — see CLAUDE.md's
   least-privilege rule)
```

## Phase 6 — Jira status names (verify, never assume)

```
🟡 offer: "Create a throwaway ticket now to read your real status names (recommended)" | "I'll tell you myself"

if create throwaway:
  bash _gateflow-shared/adapters/planning-jira.sh create-ticket --type Task \
    --summary "gateflow-init: status verification" --description-file <empty tmpfile>
  # NOTE: acli's own create/delete both worked live for a single issue in testing; if delete is
  # ever blocked by a safety classifier, tell the user the exact key and ask them to remove it.
  read back the created ticket's real status.name → seed activeWork/done candidates from what
    Jira actually returns (not from any assumed language)
  delete the throwaway ticket; if delete fails, surface the leftover key plainly, don't hide it
else:
  ask the user to state the real status names they see for "not started / in progress / done"

present the resulting jiraStatusCandidates (activeWork/inReview/done); ask to confirm or edit
```

## Phase 7 — Reviewers

```
ask: "Any GitHub usernames as default reviewers?" (blank = [] — solo project, no-op downstream)
```

## Phase 8 — Write `.gateflow/config.json`

```
assemble the object per config.schema.json's shape (version:1, vcs, planning, contentLanguage,
  sddPersistence, peRoster, reviewers, jiraStatusCandidates)
write .gateflow/config.json
✅ config written
```

## Phase 9 — CLAUDE.md

```
if CLAUDE.md already exists at the project root:
  ask: append a "## Workflow — owned by gateflow" section (skip re-adding if already present) |
       skip CLAUDE.md changes entirely
  if skip: goto End

else:
  # Universal principles — inject ONLY if the global config doesn't already look like it covers this.
  # Never duplicate a baseline that's already enforced elsewhere (same rule as everywhere else in
  # gateflow: one source of truth).
  global_config = read ~/.claude/CLAUDE.md if it exists
  has_universal_coverage = global_config is not null AND it mentions enough of:
    ["SOLID", "DRY", "YAGNI", "testing pyramid", "unit test"]   (plain keyword scan, not exhaustive —
                                                                  false positives are fine, this only
                                                                  gates an OFFER, never a silent skip)
  if not has_universal_coverage:
    🟡 offer: "Your global Claude config doesn't look like it covers SOLID/DRY/YAGNI/testing pyramid —
              add the baseline set to this project's CLAUDE.md?" (recommended: yes)
    match user_response:
      yes: universal_principles = full content of _gateflow-shared/universal-principles.md
      no:  universal_principles = "*(declined — see universal-principles.md if that changes)*"
  else:
    universal_principles = "*(covered by your global Claude Code config)*"

  read _gateflow-shared/claude-md-suggestions.md
  candidates = entries whose tags intersect stack_tags, plus every `always`-tagged entry
  for each candidate, ONE question: accept | reject (batch as a single multiSelect, default = all
    checked — user unchecks what they don't want; never silently include or silently drop one)
  accepted_principles = the accepted entries' text, concatenated
  render _gateflow-shared/claude-md-template.md with:
    PROJECT_NAME = repo directory name (or ask if it can't be inferred)
    STACK_SUMMARY = the Phase 5 stack answer, one line
    UNIVERSAL_PRINCIPLES = universal_principles
    ACCEPTED_PRINCIPLES = accepted_principles (or "*(none selected)*" if empty — never fabricate one)
  write CLAUDE.md
✅ CLAUDE.md written — "## Project-Specific Context" is deliberately blank, fill it in yourself
```

## add-pe — generate one PE later, standalone

For adding a specialist after initial setup (a new microservice in a different language, a stack that
showed up after the project already existed). Doesn't touch anything else — not `.gateflow/config.json`
wholesale, not `CLAUDE.md`.

```
stack = $ARGUMENTS after "add-pe" (ask if blank)
if ~/.claude/agents/pe-{stack}.md already exists:
  ask: overwrite | abort
  if abort: exit

run § Generate a PE with stack = {stack}

if a .gateflow/config.json exists in the current project:
  ask: "Add a pathRule for pe-{stack} to this project's config now?" (pattern + directory hint)
  if yes: append to peRoster.pathRules, rewrite .gateflow/config.json
```

## End

```
print:
  - .gateflow/config.json written (or left as-is, if Phase 0 aborted)
  - CLAUDE.md written / appended / skipped
next steps:
  - if the sdd-* skill family is installed (optional, not bundled): /sdd-init to pick this project's
    persistence mode (should match sddPersistence above), then /sdd-new <first-change>
  - otherwise: write proposal.md/tasks.md by hand for your first change — see
    requirements-artifact-contract.md for the exact shape
  - once tasks.md exists (either way): /gateflow-plan create-from-sdd <change-name>
```

## Failure handling

| Situation | Action |
|---|---|
| `.gateflow/config.json` already exists | Ask overwrite/abort — never silently clobber |
| `ensure-account` fails in Phase 2 | Stop, show the exact adapter error, don't proceed |
| Stack answer doesn't clearly imply any PE beyond the fallback | That's fine — `pe-general` alone is valid, don't force a match |
| User declines generating a PE for an unmatched stack | Route those files to `pe-general` — never force generation |
| `add-pe` targets a `pe-{stack}.md` that already exists | Ask overwrite/abort — never silently clobber an agent someone may have hand-tuned |
| Throwaway ticket delete fails (classifier or otherwise) | Surface the leftover key plainly, tell the user to remove it themselves — don't hide a stray ticket |
| CLAUDE.md already exists | Ask append-a-section vs skip — never overwrite the whole file |
| Global config keyword scan is a false positive/negative | Acceptable — it only gates an offer the user can accept or decline either way, never a silent decision |
