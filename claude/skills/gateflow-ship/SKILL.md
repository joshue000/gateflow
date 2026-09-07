---
name: gateflow-ship
description: >-
  Takes a reviewed branch to a pushed branch + GitHub pull request + Jira in-review transition. Refuses
  to proceed unless Gate 1 is locked or a logged override exists. Builds the PR body from the fixed
  four-section template. Invoked as "/gateflow-ship".
---

# gateflow-ship

Reference: `_gateflow-shared/pr-template.md`, `_gateflow-shared/gate-model.md`.

## Phase 1 — Preflight

```
config = read .gateflow/config.json
branch = git branch --show-current
if branch == config.vcs.settings.defaultBaseBranch: stop — can't ship from the base branch

if `git status --porcelain` is non-empty:
  stop — ask the user to commit or stash manually (this skill never auto-stashes a to-be-shipped branch)

key = branch matches "^([A-Z]+-\d+)" -> that key, else null
review_file = docs/gateflow/reviews/{key or slugify(branch)}-review.md
if review_file missing:
  ask: run /gateflow-review first (recommended) | proceed anyway, noting "No review performed" | abort

else:
  latest = last "## Round N" in review_file
  if not (latest.gate_status starts with "LOCKED" or starts with "OVERRIDDEN"):
    stop — "Gate 1 is not locked ({latest.gate_status}). Run /gateflow-review to remediate or override."
  if latest.sha != current HEAD:
    stop — "Review is at {latest.sha}, HEAD is now {current}. Re-run /gateflow-review."
```

## Phase 2 — Push

```
bash _gateflow-shared/adapters/vcs-github.sh current-user   # bind for later reference, not gated on
git push -u origin branch
```

## Phase 3 — PR body

Per `pr-template.md`'s four fixed sections:

```
summary_bullets   = cluster `git log {base}..HEAD --format=%s` by concept (full range, not last commit)
review_section    = latest review_file round's verdict + round number, or "No review performed"
notes_section     = omit entirely if there's nothing to say
test_plan_section = ticket.description parsed per config.planning.settings.testPlanSource, verbatim
                    — fallback: "- [ ] Verify the change locally"
                    (only if key is non-null; else always the fallback)

title = first commit subject in {base}..HEAD range   # becomes the squash-merge commit message
```

## Phase 4 — Open the PR

```
present title + body; confirm with user (edit-title / edit-body / proceed / abort)

reviewers = config.reviewers   # empty by default — solo project
result = vcs-github.sh open-pr --base base --head branch --title title --body-file <body>
         [--reviewers (join reviewers with ',') if reviewers is non-empty]
```

## Phase 5 — Jira transition

```
if key is not null:
  bash _gateflow-shared/adapters/planning-jira.sh ensure-account <config.planning.settings.site>
  planning-jira.sh transition-to key inReview
  # a transition failure here warns and prints the manual fallback — never blocks the PR that's already open
```

## End

```
print:
  - PR: {result.url}
  - Ticket: {key or "—"} -> in-review
next: "await reviewer activity, or run /gateflow-review again for Gate 2 once someone else reviews it"
```

## Failure handling

| Situation | Action |
|---|---|
| On the base branch | Stop — nothing to ship |
| Dirty tree | Stop, ask the user to resolve manually |
| No review file | Ask: run review first (recommended) / proceed anyway / abort |
| Gate 1 not locked, no override logged | Stop — this is the hard gate, never bypassed silently |
| Review SHA stale vs. HEAD | Stop, ask to re-review |
| `open-pr` fails | Stop, print the adapter's exact error |
| Jira transition fails | Warn + print manual command, PR still stands — don't roll back a successful PR over this |
