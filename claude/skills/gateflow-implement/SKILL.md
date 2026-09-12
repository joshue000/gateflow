---
name: gateflow-implement
description: >-
  Takes a Jira ticket (created by gateflow-plan, or any existing ticket) from read through working,
  tested, committed code on a branch. Scout-verified single-pass plan with a hard approval gate, then
  TDD implementation with conventional commits. Stops after commit — does not review or ship (that's
  gateflow-review / gateflow-ship). Invoked as "/gateflow-implement <TICKET-KEY>".
---

# gateflow-implement

Initial input: `$ARGUMENTS`

## Phase 1 — Resolve the ticket

```
key = match($ARGUMENTS, /^[A-Z]+-\d+$/)
if key is null: ask user for the ticket key; retry

config = read .gateflow/config.json
bash _gateflow-shared/adapters/planning-jira.sh ensure-account <config.planning.settings.site>
ticket = planning-jira.sh get-ticket key
if ticket is null: stop — "{key} not found, or wrong Jira account"

present a 3-line summary (summary, status, description excerpt); confirm with user before continuing
```

## Phase 2 — Branch

```
if `git status --porcelain` is non-empty:
  ask: commit first (exit) | stash with a named ref (restore at End) | abort
  never stash/discard without this explicit choice

base = config.vcs.settings.defaultBaseBranch, else planning-jira.sh default-branch result
git checkout base && git pull --ff-only origin base
slug = lowercase(ticket.summary) -> [a-z0-9]+ joined by '-', capped at 8 words
branch = "{key}-{slug}"
git checkout -b branch

planning-jira.sh transition-to key activeWork
```

## Phase 3 — Scout + plan (hard approval gate)

```
scout: Read/Grep/Glob only, no edits. Every file/module claim MUST be something you actually verified
this way. Anything the ticket implies but you couldn't confirm in the working tree is labeled
UNCONFIRMED — never stated as fact.

write a single consolidated plan to docs/gateflow/plans/{key}-plan.md:
  - affected files (scout-verified)
  - approach
  - AC -> behavior map (one line per ticket AC: which file/behavior satisfies it)
  - unconfirmed areas, if any

present the plan. HARD STOP:
  do NOT write any implementation code until the user replies with one of:
    approved | approve | go | lgtm | proceed | ship it
  a revision request loops back into this phase (uncapped) — never silently reinterpret feedback
```

## Phase 4 — TDD implementation

```
for each behavior in the plan:
  red:   write a failing test first — never write implementation before this exists and fails
  green: minimum code to pass
  blue:  refactor for clarity, no behavior change
  verify: run the project's actual test command after each cycle

commit each logical unit separately:
  message = "<type>: {key} <description>"   # feat|fix|chore|docs|refactor|test
  exactly one line — subject only, no body, no footers, ever. If the change needs more explanation
  than one line can hold, that explanation belongs in the PR description (gateflow-ship), not the
  commit message.
  never batch unrelated behaviors into one commit

before EVERY commit: run build + lint + test for the touched packages.
  NEW warnings (introduced by this branch, vs. the branch's starting point) must be zero.
  pre-existing warnings on touched files: ask once — fix-in-scope | accept-for-branch — don't re-ask
  per commit once answered.

if work grows beyond the approved plan's scope:
  STOP — surface the growth to the user (what the plan covered vs. what's now needed).
  options: approve the expansion (re-plan) | defer to a follow-up ticket | abort
  never silently expand scope
```

## End

```
print:
  - Ticket: {key} {ticket.summary}
  - Branch: {branch}
  - Commits: {count}
  - AC coverage: {covered}/{total} from the plan's AC -> behavior map
next steps: "/gateflow-review to check this branch, then /gateflow-ship when ready"
```

## Failure handling

| Situation | Action |
|---|---|
| Ticket not found / wrong account | Stop, exact adapter error, no guessing |
| Dirty working tree | Stop, ask (commit/stash/abort) — never act automatically |
| Base branch diverged (`pull --ff-only` fails) | Stop, do not force-reset, ask the user |
| User rejects the plan | Loop back into Phase 3 with their feedback — never loop back to Phase 2 |
| Scope expansion mid-Phase-4 | Stop, surface it, never silently proceed |
| New build/lint warnings | Fix before committing — this is a hard gate, not advisory |
