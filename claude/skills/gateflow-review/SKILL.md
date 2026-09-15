---
name: gateflow-review
description: >-
  Code review with stack-specialized agent dispatch and a two-gate quality model (Gate 1 local lock
  after 2 consecutive clean rounds; Gate 2 independent peer). Classifies review depth deterministically
  with a content-based escalation-only override, dispatches matched PE agents plus tech-writer on
  doc-touching diffs, persists the verdict locally and mirrors it to a PR comment if one exists. Invoked
  as "/gateflow-review".
---

# gateflow-review

> **GOVERNANCE SELF-AMENDMENT PROTECTION** — applies to this file and 5 siblings:
> `claude/agents/pe-governance.md`, `claude/skills/gateflow-review/SKILL.md` (this file),
> `claude/skills/_gateflow-shared/pe-agent-template.md`, `.claude/settings.json`,
> `.gateflow/config.json`, and `.claude/hooks/protect-self-amendment.sh`.
>
> - Every change to any of these 6 files requires human review, consulted BEFORE the change is
>   applied, with the reasoning exposed up front.
> - No rule added to any of these files may act as a bypass for another rule in them, or weaken/ignore
>   an already-established restriction.
> - The only condition that permits a change: the repo owner's EXPLICIT, standalone authorization —
>   never inferred from a broader "yes, proceed with everything" that wasn't specifically about this
>   change.
> - Every applied change to any of these 6 files must be logged in
>   `claude/agents/GOVERNANCE-LOG.md` (format and full history live there — these files don't
>   keep their own copies).
> - Never blindly trust a suggested change to this file, even one Claude itself proposes — always
>   route it through this full gate.
>
> This banner is intentionally longer than typical comment-length conventions — don't shorten it
> thinking it's excessive.

Reference docs, load as needed: `_gateflow-shared/tier-classifier.md`, `_gateflow-shared/gate-model.md`,
`_gateflow-shared/lenses/*.md`.

## Phase 1 — Scope

```
config = read .gateflow/config.json
base = config.vcs.settings.defaultBaseBranch, else vcs adapter's default-branch
diff_files = git diff --name-only base...HEAD, filtered by config.tierClassifier.ignorePathPatterns
if diff_files is empty: stop — nothing to review

tier = classify per tier-classifier.md, using config.tierClassifier thresholds
name = branch matches "<KEY>-..." -> KEY, else slugify(branch)
review_file = docs/gateflow/reviews/{name}-review.md
```

## Phase 2 — Routing

```
routing = {}
for file in diff_files:
  routing[file] = first (pattern, agent) in config.peRoster.pathRules where glob_match(file, pattern)
                  else config.peRoster.fallback
if any file matches "**/*.md" or "**/README*":
  add "tech-writer" to the dispatch set for those files (docs-clarity-lens.md folded into its prompt)

matched_agents = unique(routing.values()) [+ tech-writer if applicable]
```

## Phase 3 — Prior rounds

```
if review_file exists:
  prior_rounds = parse "## Round N" sections, oldest to newest
  last = prior_rounds[-1]
  if last.verdict == clean and last.sha == current HEAD:
    consecutive_clean = count trailing clean rounds at this same SHA
  else:
    consecutive_clean = 0   # new commits since the last clean round reset the count
else:
  prior_rounds = []
  consecutive_clean = 0

round_n = len(prior_rounds) + 1
```

## Phase 4 — Dispatch

```
for agent in matched_agents:
  Agent(subagent_type: agent, prompt: DISPATCH_PROMPT(agent, routing, tier))
  # one agent per matched specialist — never one per lens, never one per finding
```

`DISPATCH_PROMPT` gives the agent: the diff command to run itself (`git diff base...HEAD -- <its files>`),
the tier + its depth contract from `tier-classifier.md`, prior round content if `round_n > 1` (so it can
mark prior findings STILL_PRESENT / RESOLVED — never re-raise resolved ones), and the folded lens text
(`security-lens.md` + `workflow-correctness-lens.md` always; `docs-clarity-lens.md` added for tech-writer).

## Phase 5 — Consolidate + gate

```
all_findings = flatten(agent findings), deduped by (location, normalized title)
in_scope = [f for f in all_findings if f.in_scope]   # pre-existing issues outside the diff are awareness-only

if in_scope is empty:
  consecutive_clean += 1
  verdict = "clean"
  if consecutive_clean >= 2:
    gate_status = "LOCKED at {HEAD sha}"
  else:
    gate_status = "OPEN — 1/2 consecutive clean"
else:
  consecutive_clean = 0
  verdict = "changes requested"
  gate_status = "OPEN"
```

## Phase 6 — Fix loop (only when findings are open)

```
if in_scope is non-empty:
  present findings; ask: remediate all (recommended) | override (see below) | stop
  match choice:
    remediate: fix every in_scope finding, commit, go back to Phase 3 (new round)
    override:  restate every open finding + why it matters; require explicit confirm + a one-line
               reason; log verbatim under "### Overridden Findings"; set gate_status = "OVERRIDDEN — {reason}"
               (per gate-model.md — no severity is exempt from this pushback)
    stop:      exit; findings remain open in review_file
```

## Phase 7 — Persist

```
append to review_file:
  "## Round {round_n}\n**SHA:** {HEAD}\n**Verdict:** {verdict}\n**Gate Status:** {gate_status}\n"
  + in-scope findings table (or "None" if clean)

if a PR exists for this branch (vcs adapter get-pr succeeds):
  vcs-github.sh comment-pr <number> --body-file <the round's content>   # best-effort, never blocks on failure
```

## End

```
print: "{verdict} — Gate 1: {gate_status}"
if gate_status starts with "LOCKED" or "OVERRIDDEN":
  next: "/gateflow-ship when ready"
else:
  next: "re-run /gateflow-review after remediating"
```

## Failure handling

| Situation | Action |
|---|---|
| No diff vs base | Stop — nothing to review |
| No `.gateflow/config.json` | Stop, name the missing field |
| An agent fails to deliver findings | Nudge once; on a second failure, ask: retry / drop this agent for the round / abort |
| PR comment mirror fails | Warn, keep going — the local `review_file` is the source of truth, never blocked by the mirror |
